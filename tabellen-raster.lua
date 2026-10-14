-- PDF-Raster fuer Markdown-Tabellen. Bestehende Tabelleninhalte bleiben erhalten.
if not FORMAT:match('latex') then return {} end

local function get_widths(tbl)
  local n = #tbl.colspecs
  local custom = tbl.attributes and tbl.attributes['tbl-colwidths']
  -- Bei einigen Pandoc/Quarto-Konstellationen wird eine alleinstehende
  -- : {tbl-colwidths="[...]"}-Zeile als Caption statt als Attribut gelesen.
  if tbl.caption and tbl.caption.long then
    local caption = pandoc.utils.stringify(tbl.caption.long)
    local before, embedded = caption:match('^(.-)%s*%{%s*tbl%-colwidths%s*=%s*.-(%b[]).-}%s*$')
    if embedded then
      if not custom then custom = embedded end
      if before and before:match('%S') then
        tbl.caption.long = {pandoc.Plain({pandoc.Str(before:gsub('%s+$',''))})}
      else
        tbl.caption.long = {}
      end
    end
  end
  local widths, sum = {}, 0
  if custom then
    for v in custom:gmatch('[%d%.]+') do widths[#widths+1] = tonumber(v) end
  end
  if #widths ~= n then
    widths = {}
    for i, spec in ipairs(tbl.colspecs) do
      widths[i] = (type(spec[2]) == 'number' and spec[2] > 0) and spec[2] or (1/n)
    end
  end
  for _, w in ipairs(widths) do sum = sum + w end
  local specs = {}
  for _, w in ipairs(widths) do
    specs[#specs+1] = string.format('p{%.5f\\linewidth}', 0.90*w/sum)
  end
  return '|'..table.concat(specs,'|')..'|'
end

local function bold_headers(tbl)
  if not tbl.head or not tbl.head.rows then return end
  for _, row in ipairs(tbl.head.rows) do
    for _, cell in ipairs(row.cells) do
      for i, block in ipairs(cell.contents) do
        if block.t == 'Plain' or block.t == 'Para' then
          -- Headerinhalt erhalten, nur fett setzen
          cell.contents[i] = pandoc.Plain({pandoc.Strong(block.content)})
        end
      end
    end
  end
end

function Table(tbl)
  local spec = get_widths(tbl)
  bold_headers(tbl)
  local tex = pandoc.write(pandoc.Pandoc({tbl}), 'latex')
  local found = false
  tex = tex:gsub('(\\begin{longtable}%b[]%s*)%b{}', function(prefix)
    found = true
    return prefix..'{'..spec..'}'
  end, 1)
  if not found then return nil end
  tex = tex:gsub('\\toprule\\noalign{}', '\\hline\n\\rowcolor{gray!15}')
  tex = tex:gsub('\\midrule\\noalign{}', '\\hline')
  tex = tex:gsub('\\bottomrule\\noalign{}', '')
  tex = tex:gsub('\\bottomrule', '')
  tex = tex:gsub('([^\n]-\\\\)%s*\n', function(line)
    return line..'\n\\hline\n'
  end)
  -- Eventuelle doppelte horizontale Linien zusammenfassen.
  tex = tex:gsub('\\hline%s*\\endlastfoot', '\\endlastfoot')
  tex = tex:gsub('\\hline%s*\\hline', '\\hline')
  tex = tex:gsub('\\hline%s*\\end{longtable}', '\\hline\n\\end{longtable}')
  return pandoc.RawBlock('latex', tex)
end
