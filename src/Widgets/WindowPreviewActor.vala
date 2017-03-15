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

    public class DesktopPreviewActor : Actor
    {
        private const string DEFAULT_SCHEMA = "org.gnome.desktop.background";
        private const string DEFAULT_DESKTOP_ICON = "preferences-desktop-wallpaper";

        public int target_width { get; construct; }
        public int target_height { get; construct; }
        public int icon_size { get; construct; }
        public bool show_icon { get; construct; }
        public bool show_preview { get; construct; }

        private Actor create_desktop_preview_actor ()
        {
            GLib.Settings settings = new GLib.Settings (DEFAULT_SCHEMA);
            Gdk.Pixbuf pixbuf = null;
            try {
                string filenae = GLib.Filename.from_uri (settings.get_string ("picture-uri"));
                pixbuf = new Gdk.Pixbuf.from_file (filenae);
            } catch (Error e) {
                warning (e.message);
                return null;
            }
            Image image = new Image ();
            image.set_data (pixbuf.get_pixels (),
                    pixbuf.has_alpha ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888,
                    pixbuf.width,
                    pixbuf.height,
                    pixbuf.rowstride);
            Actor actor = new Actor ();
            float w,h;
            get_image_preferred_size (pixbuf, out w, out h);
            actor.content = image;
            actor.set_size (w, h);
            return actor;
        }

        private DesktopIcon create_desktop_icon ()
        {
            Gdk.Pixbuf icon = null;
            Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default ();
            try {
                icon = icon_theme.load_icon (DEFAULT_DESKTOP_ICON, icon_size, 0);
            } catch (Error e) {
                warning (e.message);
                return null;
            }

            Image image = new Image ();
            image.set_data (icon.get_pixels (),
                    icon.has_alpha ? Cogl.PixelFormat.RGBA_8888 : Cogl.PixelFormat.RGB_888,
                    icon.width,
                    icon.height,
                    icon.rowstride);
            DesktopIcon? actor = new DesktopIcon ();
            float w,h;
            actor.content = image;
            actor.set_size (icon_size, icon_size);
            return actor;
        }

        private void get_image_preferred_size (Gdk.Pixbuf image,
                                        out float width, out float height)
        {
            float scale_x = target_width / (float) image.width;
            float scale_y = target_height / (float) image.height;
            float scale = Math.fminf (scale_x, scale_y);
            width = image.width * scale;
            height = image.height * scale;
        }

        public DesktopPreviewActor (bool show_preview, int target_width, int target_height,
                                    bool show_icon,int icon_size)
        {
            Object (show_preview : show_preview, target_width : target_width,
                target_height : target_height, show_icon : show_icon, icon_size : icon_size);

            var box = new Actor ();
            box.add_constraint (new BindConstraint (this, BindCoordinate.SIZE, 0));
            this.width = target_width;
            this.height = target_height;
            add_child (box);

            if (show_preview)
            {
                Actor desktop_image = create_desktop_preview_actor ();
                box.add_child (desktop_image);
                box.x_align = box.y_align = ActorAlign.CENTER;
            }

            if (show_icon && icon_size > 16) {
                var icon = create_desktop_icon ();
                if (show_preview) {
                    icon.x = (target_width - icon.width)/2;
                    icon.y = target_height - icon.height;
                    add_child (icon);
                } else {
                    box.add_child (icon);
                }
            }

        }
    }

    public class WindowPreviewActor : Actor
    {
        public Window window { get; construct; }
        public int target_width { get; construct; }
        public int target_height { get; construct; }
        public int icon_size { get; construct; }
        public bool show_icon { get; construct; }

        Clone? clone = null;

        construct
        {
            set_pivot_point (0.5f, 0.5f);
			set_easing_mode (AnimationMode.EASE_OUT_ELASTIC);
			set_easing_duration (800);
        }

        public WindowPreviewActor (Window? window, int target_width, int target_height,
                                    bool show_icon, int icon_size)
        {
            Object (window : window, target_width : target_width,
                target_height : target_height, show_icon : show_icon, icon_size : icon_size);
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
            var box = new Actor ();
            box.add_constraint (new BindConstraint (this, BindCoordinate.SIZE, 0));

            float clone_prefer_width, clone_prefer_height;
			get_clone_preferred_size (out clone_prefer_width, out clone_prefer_height);
			clone.set_size (clone_prefer_width, clone_prefer_height);

            this.width = target_width;
            this.height = target_height;
            add_child (box);
            box.add_child (clone);
            box.x_align = ActorAlign.CENTER;
            box.y_align = ActorAlign.CENTER;
            if (icon_size >= 16 && show_icon) {
                var icon = new WindowIcon (window, icon_size);
                icon.x = (target_width - icon.width)/2;
                icon.y = target_height - icon.height;
                add_child (icon);
            }
        }

        void get_clone_preferred_size (out float width, out float height)
        {
            var outer_rect = window.get_frame_rect ();
            float scale_x = (target_width) / (float)outer_rect.width;
            float scale_y = (target_height) / (float)outer_rect.height;
            float scale = Math.fminf (scale_x, scale_y);

            width = outer_rect.width * scale;
            height = outer_rect.height * scale;
        }


    }
}
