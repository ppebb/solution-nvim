local nuget_ui = require("solution.ui.nuget_browser")

return {
    name = "NugetBrowser",
    func = function() nuget_ui.open() end,
}
