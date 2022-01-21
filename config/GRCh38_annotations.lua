function setid(pre,...)
 local t = {...}
 local res = {}
 local seen = {}
 for idx, ids in pairs(t) do
  local sep=","
  for v in string.gmatch(ids, "([^"..sep.."]+)") do
   for i, v in pairs(t) do
    if v ~= "." and v ~= nil and v ~= "" then
     if seen[v] == nil then
      res[#res+1] = string.gsub(pre[i] .. v, ",", ";")
      seen[v] = true
     end
    end
   end
  end
 end
 return table.concat(res, ";")
end
