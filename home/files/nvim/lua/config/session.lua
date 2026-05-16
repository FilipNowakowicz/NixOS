local ok, persistence = pcall(require, "persistence")
if not ok then
  return
end

persistence.setup()
