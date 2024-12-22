local nuget_ui = require("solution.nuget.ui")

return {
    name = "NugetBrowser",
    func = function() nuget_ui.open() end,
}
