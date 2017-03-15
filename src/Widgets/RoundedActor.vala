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
    class RoundedActor : Actor
    {
        private Canvas canvas;
        private Color back_color;
        private int rect_radius;
        private int stroke_width;
        private Color stroke_color;

        public RoundedActor (Color background_color, int radius,
                                int stroke_width, Color stroke_color)
        {
            rect_radius = radius;
            back_color = background_color;
            this.stroke_width = stroke_width % 2 == 0 ? stroke_width : stroke_width + 1;
            this.stroke_color = stroke_color;
            canvas = new Canvas ();
            this.set_content ( canvas );
            canvas.draw.connect (this.drawit);
        }

        protected virtual bool drawit ( Cairo.Context ctx)
        {
            Granite.Drawing.BufferSurface buffer;
            buffer = new Granite.Drawing.BufferSurface ((int)this.width, (int)this.height);

            /*
            * copied from popover-granite-drawing
            * https://code.launchpad.net/~tombeckmann/wingpanel/popover-granite-drawing
            */

            buffer.context.clip ();
            buffer.context.reset_clip ();

            // draw rect
            cairo_set_source_color (buffer.context, back_color);
            Granite.Drawing.Utilities.cairo_rounded_rectangle (buffer.context, 0, 0, (int)this.width, (int)this.height, rect_radius);
            buffer.context.fill ();

            //draw stroke if we need
            if (stroke_width > 1)
            {
                cairo_set_source_color (buffer.context, stroke_color);
                Granite.Drawing.Utilities.cairo_rounded_rectangle (buffer.context,
                    stroke_width/2, stroke_width/2,
                    (int)this.width - stroke_width, (int)this.height - stroke_width,
                    rect_radius>1 ? rect_radius - stroke_width/2 : rect_radius);
                buffer.context.set_line_width (stroke_width);
                buffer.context.stroke ();
            }

            //clear surface to transparent
            ctx.set_operator (Cairo.Operator.SOURCE);
            ctx.set_source_rgba (0, 0, 0, 0);
            ctx.paint ();

            //now paint our buffer on
            ctx.set_source_surface (buffer.surface, 0, 0);
            ctx.paint ();

            return true;
        }

        public void resize (int width, int height)
        {
            set_size (width, height);
            canvas.set_size (width, height);
            canvas.invalidate ();
        }

        public void renew_settings (Color background_color, int radius,
                                int stroke_width, Color stroke_color)
        {
            rect_radius = radius;
            back_color = background_color;
            this.stroke_width = stroke_width % 2 == 0 ? stroke_width : stroke_width + 1;
            this.stroke_color = stroke_color;
            canvas = new Canvas ();
            this.set_content ( canvas );
            canvas.draw.connect (this.drawit);
        }
    }
}
