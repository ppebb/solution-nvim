local nuget_ui = require("solution.nuget.ui")

return {
    name = "Nuget",
    func = function() nuget_ui.open() end,
}
