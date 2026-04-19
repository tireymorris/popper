local tabs = require("popper.tabs")

describe("open_or_switch()", function()
  it("is an exported function", function()
    assert.is_function(tabs.open_or_switch)
  end)
end)