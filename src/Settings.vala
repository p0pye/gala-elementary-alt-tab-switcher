class Settings : Granite.Services.Settings
{
    public bool all_workspaces { get; set; default = false; }
    public bool animate { get; set; default = true; }
    public bool always_on_primary_monitor { get; set; default = false; }
    public bool desktop_in_switcher { get; set; default = true; }
    public bool desktop_icon_in_switcher { get; set; default = true; }
    public int icon_size { get; set; default = 80; }
    public int icon_opacity { get; set; default = 200; }

    public string wrapper_background_color { get; set; default = "#00000035"; }
    public int wrapper_round_radius { get; set; default = 16; }
    public int wrapper_stroke_width { get; set; default = 2; }
    public string wrapper_stroke_color { get; set; default = "#0000003F"; }
    public int wrapper_padding { get; set; default = 28; }
    public int wrapper_spacing { get; set; default = 8; }

    public string indicator_background_color { get; set; default="#FFFFFF90"; }
    public int indicator_round_radius { get; set; default=8; }
    public int indicator_stroke_width { get; set; default = 0; }
    public string indicator_stroke_color { get; set; default = "#FFFFFF7F"; }
    public int indicator_border { get; set; default = 4; }

    public bool caption_visible { get; set; default = true; }
    public string caption_background_color { get; set; default = "#00000090"; }
    public int caption_round_radius { get; set; default = 12; }
    public int caption_stroke_width { get; set; default = 0; }
    public string caption_stroke_color { get; set; default = "#0000005F"; }
    public string caption_font_name { get; set; default = "Open Sans Bold"; }
    public int caption_font_size { get; set; default = 10; }
    public string caption_font_color { get; set; default = "#FFFFFF"; }
    public int caption_top_magrin { get; set; default = 2; }

    public bool preview_in_switcher { get; set; default = false; }
    public int preview_width { get; set; default = 200; }
    public int preview_height { get; set; default = 150; }
    public bool preview_show_icon { get; set; default = true; }
    public int preview_icon_size { get; set; default = 64; }

    static Settings? instance = null;

    private Settings ()
    {
        base ("org.pantheon.desktop.gala.plugins.elementary-alt-tab");
    }

    public static Settings get_default ()
    {
        if (instance == null)
            instance = new Settings ();

        return instance;
    }
}
