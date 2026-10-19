-- House Lua filter for qmd-beamer PDF decks. It gives the deck's markdown
-- classes (.lead, .note, .side-cols, .key, .chip, .back and the table sizes;
-- see references/house-style.md) their look, and adds what pandoc's beamer
-- output lacks: tables styled with their tbl-colwidths, columns kept within
-- the margins, an unnumbered appendix, and back links. Other formats pass
-- through.
--
-- Run it `at: post-quarto`. At the default stage Quarto has not yet moved the
-- tables' classes and tbl-colwidths onto the tables, so the filter would see
-- unstyled tables with equal column widths. Citations are formatted after this
-- filter, so table cells and styled blocks stay pandoc elements (not LaTeX
-- strings) wherever they may hold an @citation.
--
-- Sizes are in pt; the body text is 10 pt. To debug, print with
-- quarto.log.output(...); io.stderr output is swallowed.

if not FORMAT:match("beamer") then
  return {}
end

-- Type sizes in pt
local SIZE = {
  lead = 7.08,           -- .lead: the muted line under a title
  note = 5.90,           -- .note: under a table
  figure_note = 5.41,    -- .figure-note: above a figure
  smallprint = 6.89,     -- .smallprint: a caveat or disclosure
  side_text = 5.90,      -- .side-text: text beside a figure
  side_text_large = 7.54, -- .side-text.side-text-large
  side_table = 5.02,     -- a table inside .side-text
  subhead = 9.35,        -- ### level-3 headings
  key_text = 7.87,       -- .key definitions
  key_symbol = 8.69,     -- .key symbols
  display_math = 11.97,  -- display maths on its own paragraph
  refs = 6.69,           -- the reference list
}

local function raw(s) return pandoc.RawInline("latex", s) end
local function rawb(s) return pandoc.RawBlock("latex", s) end

local function to_latex(blocks)
  local s = pandoc.write(pandoc.Pandoc(blocks), "latex")
  return (s:gsub("%s+$", ""))
end

local function inlines_latex(inlines)
  return to_latex({ pandoc.Plain(inlines) })
end

local function has(el, class)
  return el.classes and el.classes:includes(class)
end

-- Font size and line height from a size in pt
local function size(pt, leading)
  return string.format("\\fontsize{%.2f}{%.2f}\\selectfont", pt, pt * (leading or 1.35))
end

-- Frames (by label) with a click-to-reveal step, filled by the Pandoc pass
local frames_with_overlay = {}

------------------------------------------------------------------------------
-- Maths: a colour written \color{#rrggbb} (KaTeX's form, as in slides copied
-- from an HTML deck) becomes xcolor's \color[HTML]{RRGGBB}. The theme's named
-- colours (\color{crimson}) work as they are.

local function fix_colors(text)
  return (text:gsub("\\color{#(%x%x%x%x%x%x)}", function(hex)
    return "\\color[HTML]{" .. hex:upper() .. "}"
  end))
end

local function Math(el)
  el.text = fix_colors(el.text)
  return el
end

-- Bold text inside a muted block is set in ink
local function ink_strong(inlines)
  return inlines:walk({
    Strong = function(st)
      return { raw("{\\color{ink}\\bfseries "), pandoc.Span(st.content), raw("}") }
    end,
  })
end

------------------------------------------------------------------------------
-- Tables: a tabular with hairlines between rows, a muted semibold header and
-- the widths of tbl-colwidths. Cells stay pandoc inlines so that citeproc
-- (which runs after this filter) still formats their citations.

-- Font size (pt), vertical cell padding (em), line height, horizontal cell
-- padding (em), by class
local function table_style(tbl)
  if has(tbl, "in-side-text") then return SIZE.side_table, 0.2, nil, 0.5 end
  if has(tbl, "tiny") then return 3.64, 0.06, 1.2, 0.6 end
  if has(tbl, "dense") then return 5.51, 0.2, nil, 0.6 end
  if has(tbl, "compact") then return 5.90, 0.2, nil, 0.6 end
  return 6.69, 0.3, nil, 0.45
end

-- Column widths as fractions: Quarto has put tbl-colwidths on the column specs
local function col_widths(tbl)
  local w, total = {}, 0
  for i, cs in ipairs(tbl.colspecs) do
    if type(cs[2]) ~= "number" then return nil end
    w[i] = cs[2]
    total = total + cs[2]
  end
  if total == 0 then return nil end
  for i = 1, #w do w[i] = w[i] / total end
  return w
end

local function cell_inlines(cell)
  local out = pandoc.List()
  for i, blk in ipairs(cell.contents) do
    if i > 1 then out:insert(raw("\\par ")) end
    if blk.content then out:extend(blk.content) end
  end
  return out
end

-- Table widths by class, as a share of the text width
local WIDTH = { narrow = 0.6 }

local function table_inlines(tbl)
  local pt, pad, leading, sep = table_style(tbl)
  local scale = 1.0
  for class, share in pairs(WIDTH) do
    if has(tbl, class) then scale = share end
  end
  local widths = col_widths(tbl)
  local specs = {}
  for i, cs in ipairs(tbl.colspecs) do
    local align = cs[1]
    local ragged = "\\raggedright"
    if align == "AlignRight" then ragged = "\\raggedleft" elseif align == "AlignCenter" then ragged = "\\centering" end
    -- The first column has no left padding and the last none on the right
    -- (@{}), so they get one \tabcolsep back.
    local pads = 2
    if i == 1 then pads = pads - 1 end
    if i == #tbl.colspecs then pads = pads - 1 end
    if widths then
      specs[i] = string.format(">{%s\\arraybackslash}p{\\dimexpr %.4f\\linewidth-%d\\tabcolsep\\relax}",
        ragged, widths[i] * scale, pads)
    else
      specs[i] = (align == "AlignRight") and "r" or ((align == "AlignCenter") and "c" or "l")
    end
  end

  local out = pandoc.List()
  local function add(s) out:insert(raw(s)) end
  -- No hyphenation ("Experi-ments" in a narrow header); a header word wider than its column runs
  -- into the padding instead.
  add("{" .. size(pt, leading) .. "\\let\\ttfamily\\tablemono\\setlength{\\tabcolsep}{" .. sep .. "em}" ..
    "\\hyphenpenalty=10000\\exhyphenpenalty=10000\\noindent\n")
  add("\\begin{tabular}[t]{@{}" .. table.concat(specs) .. "@{}}\n")

  local function add_row(row, header)
    for c, cell in ipairs(row.cells) do
      if c > 1 then add(" & ") end
      local inl = cell_inlines(cell)
      if header and #inl > 0 then
        add("\\leavevmode{\\color{muted}\\bfseries ")
        out:extend(inl)
        add("}")
      else
        out:extend(inl)
      end
    end
  end

  for _, row in ipairs(tbl.head.rows) do
    add_row(row, true)
    add(" \\\\[0.30em]\n")
  end
  if #tbl.head.rows > 0 then
    add(string.format("\\arrayrulecolor{ink}\\specialrule{0.53pt}{0pt}{%.2fem}\n", pad))
  end

  local body = {}
  for _, b in ipairs(tbl.bodies) do
    for _, row in ipairs(b.body) do body[#body + 1] = row end
  end
  for r, row in ipairs(body) do
    add_row(row, false)
    add(" \\\\\n")
    local last = (r == #body)
    add(string.format("\\arrayrulecolor{%s}\\specialrule{0.36pt}{%.2fem}{%s}\n",
      last and "rulegrey" or "hairline", pad, last and "0pt" or string.format("%.2fem", pad)))
  end
  add("\\end{tabular}\\par}")
  return out
end

local function Table(tbl)
  local out = pandoc.List({ raw("\\par\\vspace{-0.15em}") })
  out:extend(table_inlines(tbl))
  return pandoc.Plain(out)
end

------------------------------------------------------------------------------
-- Blocks with classes

-- A muted block of small type: size (pt), space above and below
local function styled(div, pt, before, after)
  local open = string.format("\\par\\vspace{%s}{%s\\color{muted}", before, size(pt))
  return { rawb(open), pandoc.Div(div.content), rawb("\\par}\\vspace{" .. after .. "}") }
end

-- .key: a two-column grid of [symbol]{.sym} and [definition]{.def} spans
local function key(div)
  local rows = {}
  local sym
  div:walk({
    Span = function(sp)
      if has(sp, "sym") then
        sym = sp.content:walk({ Math = Math })
      elseif has(sp, "def") and sym then
        rows[#rows + 1] = "{" .. size(SIZE.key_symbol) .. inlines_latex(sym) .. "} & \\leavevmode{\\color{muted}" ..
          inlines_latex(ink_strong(sp.content:walk({ Math = Math }))) .. "}"
        sym = nil
      end
    end,
  })
  local out = {
    "\\par\\vspace{0.3em}{\\centering" .. size(SIZE.key_text),
    "\\begin{tabular}{@{}r@{\\hspace{1.4em}}>{\\raggedright\\arraybackslash}p{80mm}@{}}",
    table.concat(rows, " \\\\\\noalign{\\vskip 0.55em}\n"),
    "\\end{tabular}\\par}",
  }
  return rawb(table.concat(out, "\n"))
end

-- Text beside a figure (.side-text, in a .columns div): smaller type, tighter
-- lists. Its tables are marked so that table_style() sizes them to match.
local function side_text(div)
  local pt = has(div, "side-text-large") and SIZE.side_text_large or SIZE.side_text
  local content = div.content:walk({
    Table = function(t)
      t.classes:insert("in-side-text")
      return t
    end,
  })
  return {
    rawb("\\par{" .. size(pt) .. "\\setlength{\\parskip}{0.7em}" ..
      "\\setlength{\\leftmargini}{1.2em}\\setlength{\\leftmarginii}{1.2em}" ..
      "\\setbeamertemplate{itemize/enumerate body begin}{\\setlength{\\parskip}{0pt}\\setlength{\\itemsep}{0.45em}}" ..
      "\\setbeamertemplate{itemize/enumerate subbody begin}{\\setlength{\\itemsep}{0.2em}\\vspace{0.2em}}"),
    pandoc.Div(content),
    rawb("\\par}"),
  }
end

-- Columns: beamer's columns environment, kept within the text width (pandoc's
-- own \begin{columns}[T] lets the columns run into the side margins). The gap
-- between columns, 3.75% of the text width in .side-cols and 1.25% otherwise,
-- comes out of the column widths. A beamer column is a
-- minipage, and a minipage sets \parskip to zero; the space between list items
-- and paragraphs on a slide is pandoc's \parskip, so each column gets it back.
local function columns(div)
  local cols = {}
  for _, c in ipairs(div.content) do
    if c.t == "Div" and has(c, "column") then cols[#cols + 1] = c end
  end
  if #cols == 0 then return nil end
  local gap = has(div, "side-cols") and 0.0375 or 0.0125
  local out = pandoc.List({ rawb("\\begin{columns}[T,onlytextwidth]") })
  for _, c in ipairs(cols) do
    local pct = tonumber(((c.attributes["width"] or ""):gsub("%%%s*$", "")))
    local frac = pct and pct / 100 or 1 / #cols
    out:insert(rawb(string.format("\\begin{column}{%.4f\\textwidth}\\setlength{\\parskip}{6pt plus 2pt minus 1pt}",
      frac * (1 - gap * (#cols - 1)))))
    out:extend(c.content)
    out:insert(rawb("\\end{column}"))
  end
  out:insert(rawb("\\end{columns}"))
  return out
end

local function styled_div(div)
  if has(div, "columns") then return columns(div) end
  if has(div, "key") then return key(div) end
  if has(div, "lead") then return styled(div, SIZE.lead, "0.25em", "0em") end
  if has(div, "note") then return styled(div, SIZE.note, "0.4em", "0pt") end
  if has(div, "smallprint") then return styled(div, SIZE.smallprint, "1.4em", "0pt") end
  if has(div, "figure-note") then return styled(div, SIZE.figure_note, "0pt", "0.4em") end
  if has(div, "side-text") then return side_text(div) end
  if div.identifier == "refs" then
    -- Smaller type, a hanging indent and some space between entries
    return {
      rawb("{" .. size(SIZE.refs) .. "\\renewenvironment{CSLReferences}[2]{\\begin{list}{}{" ..
        "\\setlength{\\leftmargin}{1.5em}\\setlength{\\itemindent}{-1.5em}" ..
        "\\setlength{\\parsep}{0pt}\\setlength{\\itemsep}{0.25em}}}{\\end{list}}"),
      div,
      rawb("\\par}"),
    }
  end
  return nil
end

local function Div(div)
  -- A .fragment block is revealed on the next click: in beamer, a \pause
  -- before it (a second page of the same frame).
  if has(div, "fragment") then
    local out = pandoc.List({ rawb("\\pause") })
    local styled_out = styled_div(div)
    if styled_out == nil then
      out:extend(div.content)
    elseif styled_out.t then
      out:insert(styled_out)
    else
      out:extend(styled_out)
    end
    return out
  end
  return styled_div(div)
end

------------------------------------------------------------------------------
-- Links and paragraphs

local function frame_target(link)
  local target = link.target:gsub("^#/?", "")
  return target
end

-- [label](#id){.chip}: an outlined link chip
local function Link(link)
  if has(link, "chip") then
    local text = inlines_latex(link.content)
    if link.target:match("^#") then
      return raw("\\hyperlink{" .. frame_target(link) .. "}{\\chip{" .. text .. "}}")
    end
    return raw("\\href{" .. link.target .. "}{\\chip{" .. text .. "}}")
  end
end

local function Para(el)
  -- A paragraph holding only [text](#id){.back} becomes a back link pinned to
  -- the bottom left of the frame. It takes no height. If the target frame has
  -- a click-to-reveal step, the link opens it with the step shown (label<2>).
  if #el.content == 1 and el.content[1].t == "Link" and has(el.content[1], "back") then
    local link = el.content[1]
    local target = frame_target(link)
    local dest = frames_with_overlay[target] and (target .. "<2>") or target
    return rawb("\\par\\nointerlineskip\\vbox to 0pt{\\noindent\\backlink{" .. dest .. "}{" ..
      inlines_latex(link.content) .. "}\\par\\vss}")
  end
end

------------------------------------------------------------------------------
-- Document pass: frame labels, the appendix, overlays, level-3 headings

local function is_pause(blk)
  return blk.t == "Para" and pandoc.utils.stringify(blk) == ". . ."
end

-- A block that holds a click-to-reveal step (a .fragment div or a pause),
-- at any depth, e.g. inside columns
local function has_step(blk)
  if is_pause(blk) or (blk.t == "Div" and has(blk, "fragment")) then return true end
  local found = false
  if blk.t == "Div" then
    blk:walk({
      Div = function(d) if has(d, "fragment") then found = true end end,
      Para = function(p) if is_pause(p) then found = true end end,
    })
  end
  return found
end

local function display_math(blk)
  return blk.t == "Para" and #blk.content == 1 and blk.content[1].t == "Math" and
    blk.content[1].mathtype == "DisplayMath"
end

local function Pandoc(doc)
  local out = pandoc.List()
  local frame = ""
  local previous
  local in_appendix = false
  for _, blk in ipairs(doc.blocks) do
    -- (An id, not an .appendix class: Quarto gives that class its own
    -- meaning in other formats.)
    if blk.t == "Header" and blk.level == 1 and blk.identifier == "appendix" then
      -- The appendix: an unnumbered frame with no title that draws the
      -- divider; every later frame is unnumbered too (beamer_theme.tex).
      in_appendix = true
      frame = blk.identifier ~= "" and blk.identifier or "appendix"
      local attr = pandoc.Attr(frame, { "noframenumbering" }, { { "label", frame } })
      out:insert(pandoc.Header(2, {}, attr))
      out:insert(rawb("\\appendixdivider{" .. inlines_latex(blk.content) .. "}"))
      previous = nil
    else
      if blk.t == "Header" and blk.level == 2 then
        frame = blk.identifier
        if frame ~= "" then blk.attributes["label"] = frame end
        if in_appendix then blk.classes:insert("noframenumbering") end
      elseif blk.t == "Header" and blk.level == 3 then
        -- Level-3 headings: muted serif subheads, with no space above when
        -- right under the frame title
        local before = (previous and previous.t == "Header" and previous.level == 2) and "0pt" or "0.25em"
        blk.attributes["subhead"] = string.format("%.2f|%s|%s", SIZE.subhead, before, "0.1em")
      elseif has_step(blk) then
        if frame ~= "" then frames_with_overlay[frame] = true end
      elseif display_math(blk) then
        -- Display maths on its own paragraph is set larger and centred
        local text = fix_colors(blk.content[1].text)
        blk = rawb("\\par\\vspace{2.6mm}{\\centering" .. size(SIZE.display_math) ..
          "$\\displaystyle " .. text .. "$\\par}\\vspace{2.2mm}")
      end
      out:insert(blk)
      previous = blk
    end
  end
  doc.blocks = out
  return doc
end

local function Header(el)
  local spec = el.attributes["subhead"]
  if el.level == 3 and spec then
    local pt, before, after = spec:match("([^|]+)|([^|]+)|([^|]+)")
    return rawb(string.format("\\slidesubhead{%s}{%s}{%s}{%s}", pt, before, after, inlines_latex(el.content)))
  end
end

return {
  { Pandoc = Pandoc },
  { Div = Div },
  { Math = Math, Para = Para, Header = Header, Table = Table, Link = Link },
}
