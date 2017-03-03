//
//  Modified by Popye [sailor3101@gmail.com], 2017
//
//	Original copyright (C) 2014, Tom Beckmann
//	https://github.com/tom95/gala-alternate-alt-tab
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
	public delegate void ObjectCallback (Object object);

	class Settings : Granite.Services.Settings
	{
		public bool all_workspaces { get; set; default = false; }
		public bool animate { get; set; default = true; }
		public bool always_on_primary_monitor { get; set; default = false; }
		public int icon_size { get; set; default = 64; }
		public string font_name { get; set; default = "Roboto Mono"; }
		public string font_color { get; set; default = "#ffffff"; }

		public string wrapper_background_color { get; set; default = "#00000035"; }
		public int wrapper_round_radius { get; set; default = 16; }
		public int wrapper_stroke_width { get; set; default = 2; }
		public string wrapper_stroke_color { get; set; default = "#0000003F"; }

		public string indicator_background_color { get; set; default="#FFFFFF90"; }
		public int indicator_round_radius { get; set; default=8; }
		public int indicator_stroke_width { get; set; default = 0; }
		public string indicator_stroke_color { get; set; default = "#FFFFFF7F"; }

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

	public class Main : Gala.Plugin
	{
		const int SPACING = 12;
		const int SPACING_VERT = 4;
		const int PADDING = 24;
		const int MIN_OFFSET = 64;
		const int INDICATOR_BORDER = 6;
		const double ANIMATE_SCALE = 0.8;


		public bool opened { get; private set; default = false; }

		Gala.WindowManager? wm = null;
		Gala.ModalProxy modal_proxy = null;
		Actor container;
		RoundedActor wrapper;
		RoundedActor indicator;
		Text app_caption;

		int modifier_mask;

		WindowIcon? current = null;

		public override void initialize (Gala.WindowManager wm)
		{
			this.wm = wm;
			var settings = Settings.get_default ();

			KeyBinding.set_custom_handler ("switch-applications", (Meta.KeyHandlerFunc) handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-applications-backward", (Meta.KeyHandlerFunc) handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows", (Meta.KeyHandlerFunc) handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows-backward", (Meta.KeyHandlerFunc) handle_switch_windows);

			var layout = new FlowLayout (FlowOrientation.HORIZONTAL);
			layout.column_spacing = layout.row_spacing = SPACING;

			wrapper = new RoundedActor (Color.from_string (settings.wrapper_background_color),
				settings.wrapper_round_radius, settings.wrapper_stroke_width, Color.from_string (settings.wrapper_stroke_color));
			wrapper.reactive = true;
			wrapper.set_pivot_point (0.5f, 0.5f);
			wrapper.key_release_event.connect (key_relase_event);

			container = new Actor ();
			container.layout_manager = layout;
			container.reactive = true;
			container.margin_left = container.margin_top =
				container.margin_right = container.margin_bottom = PADDING;
			container.button_press_event.connect (container_mouse_press);
			container.motion_event.connect (container_motion_event);

			indicator = new RoundedActor (Color.from_string (settings.indicator_background_color), settings.indicator_round_radius,
				settings.indicator_stroke_width, Color.from_string (settings.indicator_stroke_color));

			indicator.margin_left = indicator.margin_top =
				indicator.margin_right = indicator.margin_bottom = 0;
			indicator.set_easing_duration (200);
			indicator.set_pivot_point (0.5f, 0.5f);

			/*app_caption = new Text.full (settings.font_name, "Some window name here!", Color.from_string (settings.font_color));
			app_caption.background_color = { 0, 0, 0, 150 };*/

			wrapper.add_child (indicator);
			wrapper.add_child (container);
		}

		bool container_motion_event (MotionEvent event)
		{
			var selected = event.stage.get_actor_at_pos (PickMode.ALL, (int) event.x, (int) event.y) as WindowIcon;
			if (selected == null)
				return true;

			current = selected;
			update_indicator_position ();
			return true;
		}

		bool container_mouse_press (ButtonEvent event)
		{
			if (opened && event.button == Gdk.BUTTON_PRIMARY)
				close_switcher (event.time);
			return true;
		}

		public override void destroy ()
		{
			wrapper.destroy ();
			container.destroy ();
			indicator.destroy ();
			app_caption.destroy ();

			if (wm == null)
				return;

		}

		[CCode (instance_pos = -1)] void handle_switch_windows (
					Display display, Screen screen, Window? window,
		#if HAS_MUTTER314
					Clutter.KeyEvent event, KeyBinding binding)
		#else
					X.Event event, KeyBinding binding)
		#endif
		{
			var settings = Settings.get_default ();
			var workspace = settings.all_workspaces ? null : screen.get_active_workspace ();

			// copied from gnome-shell, finds the primary modifier in the mask
			var mask = binding.get_mask ();
			if (mask == 0)
				modifier_mask = 0;
			else {
				modifier_mask = 1;
				while (mask > 1) {
					mask >>= 1;
					modifier_mask <<= 1;
				}
			}

			if (!opened) {
				collect_windows (display, workspace);
				open_switcher ();
				update_indicator_position (true);
			}

			var binding_name = binding.get_name ();
			var backward = binding_name.has_suffix ("-backward");

			// FIXME for unknown reasons, switch-applications-backward won't be emitted, so we
			//       test manually if shift is held down
			/*backward = false;
			backward = binding_name == "switch-applications-backward";
			//	&& (get_current_modifiers () & ModifierType.SHIFT_MASK) != 0;*/
			next_window (display, workspace, backward);
		}

		void collect_windows (Display display, Workspace? workspace)
		{
			var settings = Settings.get_default ();

			var windows = display.get_tab_list (TabList.NORMAL, workspace);
			var current_window = display.get_tab_current (TabList.NORMAL, workspace);

			container.width = -1;
			container.destroy_all_children ();
			foreach (var window in windows) {
				var icon = new WindowIcon (window, settings.icon_size);
				if (window == current_window)
					current = icon;

				container.add_child (icon);
			}
		}

		void open_switcher ()
		{
			if (container.get_n_children () == 0) {
				return;
			}

			if (opened)
				return;

			var screen = wm.get_screen ();
			var settings = Settings.get_default ();

			//renew settings for actors
			wrapper.renew_settings (Color.from_string (settings.wrapper_background_color),
				settings.wrapper_round_radius, settings.wrapper_stroke_width, Color.from_string (settings.wrapper_stroke_color));
			indicator.renew_settings(Color.from_string (settings.indicator_background_color), settings.indicator_round_radius,
				settings.indicator_stroke_width, Color.from_string (settings.indicator_stroke_color));

			indicator.visible = false;
			indicator.resize (settings.icon_size + INDICATOR_BORDER * 2, settings.icon_size + INDICATOR_BORDER * 2);

			if (settings.animate) {
				wrapper.opacity = 0;
				wrapper.set_scale (ANIMATE_SCALE, ANIMATE_SCALE);
			}

			var monitor = settings.always_on_primary_monitor ?
				screen.get_primary_monitor () : screen.get_current_monitor ();
			var geom = screen.get_monitor_geometry (monitor);

			float container_width;
			container.get_preferred_width (settings.icon_size + PADDING * 2, null, out container_width);
			if (container_width + MIN_OFFSET * 2 > geom.width)
				container.width = geom.width - MIN_OFFSET * 2;

			float nat_width, nat_height;
			if (container.get_n_children () == 1)
				container.get_preferred_size (out nat_width, null, null, null);
			else
				container.get_preferred_size (null, null, out nat_width, null);

			container.get_preferred_size (null, out nat_height, null, null);
			wrapper.resize ((int) nat_width, (int) nat_height);
			wrapper.set_position (geom.x + (geom.width - wrapper.width) / 2,
			                      geom.y + (geom.height - wrapper.height) / 2);

			wm.ui_group.insert_child_above (wrapper, null);

			wrapper.save_easing_state ();
			wrapper.set_easing_duration (100);
			wrapper.set_scale (1, 1);
			wrapper.opacity = 255;
			wrapper.restore_easing_state ();

			modal_proxy = wm.push_modal ();
			modal_proxy.keybinding_filter = keybinding_filter;
			opened = true;

			wrapper.grab_key_focus ();

			// if we did not have the grab before the key was released, close immediately
			if ((get_current_modifiers () & modifier_mask) == 0)
				close_switcher (screen.get_display ().get_current_time ());
		}

		void close_switcher (uint32 time)
		{
			if (!opened)
				return;

			wm.pop_modal (modal_proxy);
			opened = false;

			ObjectCallback remove_actor = () => {
				wm.ui_group.remove_child (wrapper);
			};

			if (Settings.get_default ().animate) {
				wrapper.save_easing_state ();
				wrapper.set_easing_duration (100);
				wrapper.set_scale (ANIMATE_SCALE, ANIMATE_SCALE);
				wrapper.opacity = 0;

				var transition = wrapper.get_transition ("opacity");
				if (transition != null)
					transition.completed.connect (() => remove_actor (this));
				else
					remove_actor (this);

				wrapper.restore_easing_state ();
			} else {
				remove_actor (this);
			}

			if (current.window == null) {
				return;
			}

			var window = current.window;
			var workspace = window.get_workspace ();
			if (workspace != wm.get_screen ().get_active_workspace ())
				workspace.activate_with_focus (window, time);
			else
				window.activate (time);
		}

		void next_window (Display display, Workspace? workspace, bool backward)
		{
			Actor actor;
			if (!backward) {
				actor = current.get_next_sibling ();
				if (actor == null)
					actor = container.get_child_at_index (0);
			} else {
				actor = current.get_previous_sibling ();
				if (actor == null)
					actor = container.get_child_at_index (container.get_n_children () - 1);
			}

			current = (WindowIcon) actor;

			update_indicator_position ();
		}

		void update_indicator_position (bool initial = false)
		{
			// FIXME there are some troubles with layouting, in some cases we
			//       are here too early, in which case all the children are at
			//       (0|0), so we can easily check for that and come back later
			if (container.get_n_children () > 1
				&& container.get_child_at_index (1).allocation.x1 < 1) {

				Idle.add (() => {
					update_indicator_position (initial);
					return false;
				});
				return;
			}

			float x, y;
			current.allocation.get_origin (out x, out y);

			if (initial) {
				indicator.visible = true;
				indicator.save_easing_state ();
				indicator.set_easing_duration (0);
			}

			indicator.x = container.margin_left + x - INDICATOR_BORDER;
			indicator.y = container.margin_top + y - INDICATOR_BORDER;

			if (initial)
				indicator.restore_easing_state ();
		}

		bool key_relase_event (KeyEvent event)
		{
			if ((get_current_modifiers () & modifier_mask) == 0) {
				close_switcher (event.time);
				return true;
			}

			switch (event.keyval) {
				case Key.Escape:
					close_switcher (event.time);
					return true;
			}

			return false;
		}

		Gdk.ModifierType get_current_modifiers ()
		{
			Gdk.ModifierType modifiers;
			double[] axes = {};
			Gdk.Display.get_default ().get_device_manager ().get_client_pointer ()
				.get_state (Gdk.get_default_root_window (), axes, out modifiers);

			return modifiers;
		}

		bool keybinding_filter (KeyBinding binding)
		{
			// don't block any keybinding for the time being
			// return true for any keybinding that should be handled here.
			return false;
		}
	}
}

public Gala.PluginInfo register_plugin ()
{
	return Gala.PluginInfo () {
		name = "Elementary Alt Tab",
		author = "Gala Developers, Popye",
		plugin_type = typeof (Gala.Plugins.ElementaryAltTab.Main),
		provides = Gala.PluginFunction.WINDOW_SWITCHER,
		load_priority = Gala.LoadPriority.IMMEDIATE
	};
}
