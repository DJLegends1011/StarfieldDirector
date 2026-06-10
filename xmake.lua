-- include subprojects
includes("lib/commonlibsf")

-- set project constants
set_project("starfield-director")
set_version("0.0.1")
set_license("GPL-3.0")
set_languages("c++23")
set_warnings("allextra")

-- add common rules
add_rules("mode.debug", "mode.releasedbg")
add_rules("plugin.vsxmake.autoupdate")

-- define targets
target("Director")
    add_rules("commonlibsf.plugin", {
        name = "Director",
        author = "DJLegends",
        description = "AI Director for Starfield",
        contact = "dkidd799@gmail.com"
    })

    -- add src files
    add_files("src/**.cpp")
    add_headerfiles("src/**.h")
    add_includedirs("src")
    set_pcxxheader("src/pch.h")
