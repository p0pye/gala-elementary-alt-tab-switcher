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
    class Utils
    {
        /*
        *	copied from deepin utils
        */
        public static void show_desktop (Meta.Workspace workspace)
        {
            // FIXME: this is a temporary solution, should send _NET_SHOWING_DESKTOP instead, but
            // mutter could not dispatch it correctly for issue
            var screen = workspace.get_screen ();
            var display = screen.get_display ();
            var windows = display.get_tab_list (Meta.TabList.NORMAL, workspace);
            var hide_all = false;

            foreach (var w in windows) {
                if (!w.minimized) {
                    hide_all = true;
                    break;
                }
            }

            if (hide_all) {
                foreach (var w in windows)
                    w.minimize ();
            }
            else {
                foreach (var w in windows)
                    w.unminimize ();
            }
        }

        public static void icon_fade (Actor act, bool _in=true)
        {
            if (act == null)
                return;
            if (_in){
                act.save_easing_state ();
                act.set_easing_duration (200);
                act.opacity = 255;
                act.restore_easing_state ();
            } else {
                act.save_easing_state ();
                act.set_easing_duration (200);
                act.opacity = Settings.get_default ().icon_opacity;
                act.restore_easing_state ();
            }
        }
    }
}
