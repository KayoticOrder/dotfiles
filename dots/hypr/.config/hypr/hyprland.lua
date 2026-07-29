-- Hyprland config (migrated from hyprland.conf, see git history)
-- https://wiki.hypr.land/Configuring/Start/

------------------
---- MONITORS ----
------------------

hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x1440@120", position = "2560x0", scale = 1 })
hl.monitor({ output = "DP-3", mode = "2560x1440@120", position = "5120x0", scale = 1 })


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper & waybar & dunst & fcitx5")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse                 = 2,
        float_switch_override_focus  = 0,

        sensitivity = -1.0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },

    cursor = {
        inactive_timeout    = 3,
        no_hardware_cursors = 1,
    },
})


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 3,
        gaps_out    = 10,
        border_size = 2,

        col = {
            active_border   = "rgba(D5CD9BFF)",
            inactive_border = "rgba(363748FF)",
        },

        layout = "dwindle",
    },

    decoration = {
        fullscreen_opacity = 0.97,
        inactive_opacity   = 0.97,
        active_opacity     = 0.97,

        rounding = 8,

        blur = {
            enabled = true,
            size    = 3,
            passes  = 3,
        },

        shadow = {
            range        = 10,
            render_power = 1,
            color        = "rgba(0000004e)",
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("windBez", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("workBez", { type = "bezier", points = { {0.85, 0.0}, {0.13, 1.0} } })

hl.animation({ leaf = "windows",     enabled = true, speed = 4, bezier = "windBez" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 4, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 3, bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 3, bezier = "workBez" })

hl.config({
    debug = {
        vfr = false, -- variable frame rate (might want to disable to save resources)
    },

    dwindle = {
        preserve_split = true, -- you probably want this
    },

    master = {
        new_status = "master",
    },
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("alacritty"))
hl.bind(mainMod .. " + W",      hl.dsp.window.close())
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("alacritty ranger"))
hl.bind(mainMod .. " + F",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + M",      hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + END",    hl.dsp.exit())
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/rofi/scripts/launcher_t1"))
hl.bind(mainMod .. " + P",      hl.dsp.window.pseudo())    -- dwindle
hl.bind(mainMod .. " + G",      hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("discord --enable-features=UseOzonePlatform --ozone-platform=wayland"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("code --enable-features=UseOzonePlatform --ozone-platform=wayland"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("spotify --enable-features=UseOzonePlatform --ozone-platform=wayland"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("mkdir -p ~/screenshots && grim -g \"$(slurp -d)\" - | tee ~/screenshots/$(date +'%Y%m%d_%H%M%S').png | wl-copy"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/scripts/record_audio_toggle.sh"))

hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl -p spotify,% previous"))
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl -p spotify,% next"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("playerctl -p spotify,% volume 0.05-"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("playerctl -p spotify,% volume 0.05+"))
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl -p spotify,% play-pause"))

-- Move focus/move with mainMod + shift + vimkeys
hl.bind(mainMod .. " + H",         hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L",         hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K",         hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J",         hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.workspace_rule({ workspace = "5", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "6", monitor = "DP-1" })
hl.workspace_rule({ workspace = "7", monitor = "DP-1" })

hl.workspace_rule({ workspace = "1", monitor = "DP-2", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-2" })
hl.workspace_rule({ workspace = "3", monitor = "DP-2" })
hl.workspace_rule({ workspace = "4", monitor = "DP-2" })

hl.workspace_rule({ workspace = "8",  monitor = "DP-3", default = true })
hl.workspace_rule({ workspace = "9",  monitor = "DP-3" })
hl.workspace_rule({ workspace = "10", monitor = "DP-3" })
