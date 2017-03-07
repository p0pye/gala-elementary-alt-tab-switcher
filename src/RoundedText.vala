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

using Clutter;

namespace Gala.Plugins.ElementaryAltTab
{
    class RoundedText : RoundedActor
    {
        private Text text;
        private const int MARGIN_TOP_BOTTOM = 2;
        private const int MARGIN_LEFT_RIGHT = 16;
        Actor parent;

        public RoundedText (Color background_color, int radius,
                    int stroke_width, Color stroke_color,
                    string text_font, string caption, Color text_color, Actor parent)
        {
            base (background_color, radius, stroke_width, stroke_color);
            text = new Text.full (text_font, caption, text_color);
            this.add_child (text);
            text.margin_top=text.margin_bottom=MARGIN_TOP_BOTTOM;
            text.margin_left=text.margin_right=MARGIN_LEFT_RIGHT;

            this.parent = parent;
        }

        public new void renew_settings (Color background_color, int radius,
                                int stroke_width, Color stroke_color,
                                string text_font, Color text_color)
        {
            base.renew_settings (background_color, radius, stroke_width, stroke_color);
            this.text.set_font_name (text_font);
            this.text.set_color (text_color);
        }

        public void autosize ()
        {
            //cut long text
            while (text.width > parent.width)
            {
                text.text = "%s...".printf (text.text.substring (0, text.text.length-4) );
            }

            base.resize ((int) text.width, (int) text.height);
        }

        public void set_text (string value)
        {
            this.text.text = value;
            this.autosize ();
        }
    }
}
