//  Copyright (C) 2017, Popye [sailor3101@gmail.com]
//
//  based on DeepinWindowSwitcherItem
//  https://github.com/linuxdeepin/deepin-wm/blob/master/src/Deepin/DeepinWindowSwitcherItem.vala
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
using Meta;

namespace Gala.Plugins.ElementaryAltTab
{
    public class DesktopIcon : Actor {}

    public enum VAlign {
        TOP = 0,
        BOTTOM = 1
    }

    public enum HAlign {
        LEFT = 0,
        RIGHT = 1,
        CENTER = 2
    }

    /*
    *   base class
    */
    public class PreviewActor : Actor
    {
        protected Settings settings = Settings.get_default ();
        protected Actor box;

        construct
        {
            set_pivot_point (0.5f, 0.5f);
            set_easing_duration (200);
        }

        public PreviewActor ()
        {
            box = new Actor ();
            box.add_constraint (new BindConstraint (this, BindCoordinate.SIZE, 0));
            box.x_align = box.y_align = ActorAlign.CENTER;
            add_child (box);
            //for correct drawing
            if (settings.preview_in_switcher)
                box.set_size (settings.preview_width, settings.preview_height);
        }

        protected void apply_icon_position (Actor icon)
        {
            switch (settings.preview_icon_halign) {
                case HAlign.LEFT:
                    icon.x = 0;
                    break;
                case HAlign.RIGHT:
                    icon.x = settings.preview_width - icon.width;
                    break;
                case HAlign.CENTER:
                    icon.x = (settings.preview_width - icon.width)/2;
                    break;
            }

            switch (settings.preview_icon_valign) {
                case VAlign.TOP:
                    icon.y = 00;
                    break;
                case VAlign.BOTTOM:
                    icon.y = settings.preview_height - icon.height;
                    break;
            }
        }
    }

    public class DesktopPreviewActor : PreviewActor
    {
        private const string DEFAULT_SCHEMA = "org.gnome.desktop.background";
        private const string DEFAULT_DESKTOP_ICON = "preferences-desktop-wallpaper";

        private Actor? create_desktop_preview_actor (int preview_width, int preview_height)
        {
            GLib.Settings settings = new GLib.Settings (DEFAULT_SCHEMA);

            if (settings.get_string ("picture-options") == "none") {
                Actor actor = new Actor ();
                actor.set_size (preview_width, preview_height);
                actor.background_color = Color.from_string (settings.get_string ("primary-color"));
                return actor;
            }

            Gdk.Pixbuf pixbuf = null;
            try {
                string desktop_background = GLib.Filename.from_uri (settings.get_string ("picture-uri"));
                pixbuf = new Gdk.Pixbuf.from_file_at_size (desktop_background, preview_width * 2, preview_height * 2);
            } catch (Error e) {
                warning (e.message);
                return null;
            }
            Image image = new Image ();
            try {
                image.set_data (pixbuf.get_pixels (),
                        pixbuf.has_alpha ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888,
                        pixbuf.width, pixbuf.height, pixbuf.rowstride);
            } catch (Error e) {
                warning (e.message);
            }
            Actor actor = new Actor ();
            float w,h;
            get_image_preferred_size (pixbuf, out w, out h);
            actor.content = image;
            actor.set_size (w, h);
            return actor;
        }

        private DesktopIcon? create_desktop_icon ()
        {
            Gdk.Pixbuf icon = null;
            Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default ();
            try {
                icon = icon_theme.load_icon (DEFAULT_DESKTOP_ICON, settings.preview_icon_size, 0);
            } catch (Error e) {
                warning (e.message);
                return null;
            }

            Image image = new Image ();
            try {
                image.set_data (icon.get_pixels (),
                    icon.has_alpha ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888,
                    icon.width, icon.height, icon.rowstride);
            } catch (Error e) {
                warning (e.message);
            }
            DesktopIcon? actor = new DesktopIcon ();
            actor.content = image;
            if (settings.preview_in_switcher)
                actor.set_size (settings.preview_icon_size, settings.preview_icon_size);
            else actor.set_size (settings.icon_size, settings.icon_size);
            return actor;
        }

        private void get_image_preferred_size (Gdk.Pixbuf image,
                                        out float width, out float height)
        {
            float scale_x = settings.preview_width / (float) image.width;
            float scale_y = settings.preview_height / (float) image.height;
            float scale = Math.fminf (scale_x, scale_y);
            width = image.width * scale;
            height = image.height * scale;
        }

        public DesktopPreviewActor ()
        {
            base ();
            if (settings.preview_in_switcher)
            {
                Actor desktop_image = create_desktop_preview_actor
                    ((int) (settings.preview_width),
                     (int) (settings.preview_height));
                desktop_image.y = (box.height - desktop_image.height) / 2;
                box.add_child (desktop_image);
            }

            if (settings.preview_show_icon && settings.preview_icon_size > 16) {
                var icon = create_desktop_icon ();
                if (settings.preview_in_switcher) {
                    apply_icon_position (icon);
                    add_child (icon);
                } else {
                    box.add_child (icon);
                }
            }

        }
    }

    public class WindowPreviewActor : PreviewActor
    {
        public Window window { get; private set; }
        Clone? clone = null;

        public WindowPreviewActor (Window? window)
        {
            base ();
            this.window = window;
            update_preview ();
        }

        public void update_preview ()
        {
            var actor = window.get_compositor_private () as WindowActor;
            if (actor == null) {
                Idle.add (() => {
                    if (window.get_compositor_private () != null) {
                        update_preview ();
                    }
                    return false;
                    });

                return;
            }

            clone = new Clone (actor.get_texture ());

            float clone_prefer_width, clone_prefer_height;
			get_clone_preferred_size (out clone_prefer_width, out clone_prefer_height);
			clone.set_size (clone_prefer_width, clone_prefer_height);
            clone.y = (box.height - clone.height) / 2;
            box.add_child (clone);
            if (settings.preview_icon_size >= 16 && settings.preview_show_icon) {
                var icon = new WindowIcon (window, settings.preview_icon_size);
                apply_icon_position (icon);
                add_child (icon);
            }
        }

        void get_clone_preferred_size (out float width, out float height)
        {
            var outer_rect = window.get_frame_rect ();
            float scale_x = (settings.preview_width) / (float)outer_rect.width;
            float scale_y = (settings.preview_height) / (float)outer_rect.height;
            float scale = Math.fminf (scale_x, scale_y);

            width = outer_rect.width * scale;
            height = outer_rect.height * scale;
        }


    }
}
