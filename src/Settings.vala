//  Copyright (C) 2017, Popye [sailor3101@gmail.com]
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//


namespace Gala.Plugins.ElementaryAltTab
{
    public class Settings : Granite.Services.Settings
    {
        public bool all_workspaces { get; set; default = false; }
        public bool animate { get; set; default = true; }
        public bool always_on_primary_monitor { get; set; default = false; }
        public bool desktop_in_switcher { get; set; default = true; }
        public bool desktop_icon_in_switcher { get; set; default = true; }
        public string desktop_display_name { get; set; default = "Desktop"; }
        public double inactive_element_scale { get; set; default = 0.8; }
        public double active_element_scale { get; set; default = 1.0; }

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

        public HAlign preview_icon_halign { get; set; default = HAlign.CENTER; }
        public VAlign preview_icon_valign { get; set; default = VAlign.BOTTOM; }

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
}
