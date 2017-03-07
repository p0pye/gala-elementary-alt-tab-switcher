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

	public const string SWITCHER_PLUGIN_VERSION="0.1.2";

	class Settings : Granite.Services.Settings
	{
		public bool all_workspaces { get; set; default = false; }
		public bool animate { get; set; default = true; }
		public bool always_on_primary_monitor { get; set; default = false; }
		public int icon_size { get; set; default = 80; }
		public int icon_opacity { get; set; default = 200; }

		public string wrapper_background_color { get; set; default = "#00000035"; }
		public int wrapper_round_radius { get; set; default = 16; }
		public int wrapper_stroke_width { get; set; default = 2; }
		public string wrapper_stroke_color { get; set; default = "#0000003F"; }

		public string indicator_background_color { get; set; default="#FFFFFF90"; }
		public int indicator_round_radius { get; set; default=8; }
		public int indicator_stroke_width { get; set; default = 0; }
		public string indicator_stroke_color { get; set; default = "#FFFFFF7F"; }

		public bool caption_visible { get; set; default = true; }
		public string caption_background_color { get; set; default = "#00000090"; }
		public int caption_round_radius { get; set; default = 12; }
		public int caption_stroke_width { get; set; default = 0; }
		public string caption_stroke_color { get; set; default = "#0000005F"; }
		public string caption_font_name { get; set; default = "Open Sans Bold"; }
		public int caption_font_size { get; set; default = 10; }
		public string caption_font_color { get; set; default = "#FFFFFF"; }

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
		const int SPACING = 4;
		const int PADDING = 28;
		const int MIN_OFFSET = 64;
		const int INDICATOR_BORDER = 2;
		const int FIX_TIMEOUT_INTERVAL = 100;
		const double ANIMATE_SCALE = 0.8;


		public bool opened { get; private set; default = false; }

		Gala.WindowManager? wm = null;
		Gala.ModalProxy modal_proxy = null;
		Actor container;
		RoundedActor wrapper;
		RoundedActor indicator;
		RoundedText caption;

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
			indicator.set_easing_duration (settings.animate ? 200 : 0);
			indicator.set_pivot_point (0.5f, 0.5f);

			caption = new RoundedText (Color.from_string (settings.caption_background_color), settings.caption_round_radius,
				settings.caption_stroke_width, Color.from_string (settings.caption_stroke_color),
				"%s %d".printf (settings.caption_font_name, settings.caption_font_size),
				"  ", Color.from_string (settings.caption_font_color), container);
			caption.set_pivot_point (0.5f, 0.5f);

			wrapper.add_child (indicator);
			wrapper.add_child (container);
			wrapper.add_child (caption);
		}

		bool container_motion_event (MotionEvent event)
		{
			var selected = event.stage.get_actor_at_pos (PickMode.ALL, (int) event.x, (int) event.y) as WindowIcon;
			if (selected == null)
				return true;

			if (current != selected) {
				if (Settings.get_default ().animate)
					icon_fade (current, false);
				current = selected;
				update_indicator_position ();
			}
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
			caption.destroy ();

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
				else if (settings.animate)
					icon.opacity = settings.icon_opacity;

				container.add_child (icon);
			}
		}

		void open_switcher ()
		{
			if (container.get_n_children () == 0) {
				return;
			} else if (container.get_n_children () == 1) {
				if (current == null)
					return;

				var window = current.window;
				var workspace = wm.get_screen ().get_active_workspace ();

				if (!window.minimized && workspace == window.get_workspace ()) {
					return;
				}
			}

			if (opened)
				return;

			var screen = wm.get_screen ();
			var settings = Settings.get_default ();

			//renew settings for actors
			wrapper.renew_settings (
				Color.from_string (settings.wrapper_background_color),
				settings.wrapper_round_radius,
				settings.wrapper_stroke_width,
				Color.from_string (settings.wrapper_stroke_color)
			);

			indicator.renew_settings(
				Color.from_string (settings.indicator_background_color),
				settings.indicator_round_radius,
				settings.indicator_stroke_width,
				Color.from_string (settings.indicator_stroke_color)
			);
			caption.renew_settings (
				Color.from_string (settings.caption_background_color),
				settings.caption_round_radius,
				settings.caption_stroke_width,
				Color.from_string (settings.caption_stroke_color),
				"%s %d".printf (settings.caption_font_name, settings.caption_font_size),
				Color.from_string (settings.caption_font_color)
			);

			indicator.visible = false;
			indicator.resize (settings.icon_size + INDICATOR_BORDER * 2, settings.icon_size + INDICATOR_BORDER * 2);
			caption.visible = false;

			if (settings.animate) {
				wrapper.opacity = 0;
				wrapper.set_scale (ANIMATE_SCALE, ANIMATE_SCALE);
			}

			var monitor = settings.always_on_primary_monitor ?
				screen.get_primary_monitor () : screen.get_current_monitor ();
			var geom = screen.get_monitor_geometry (monitor);

			float container_width;
			container.get_preferred_width (settings.icon_size +
				container.margin_left + container.margin_right, null, out container_width);
			if (container_width + MIN_OFFSET * 2 > geom.width)
				container.width = geom.width - MIN_OFFSET * 2;

			float nat_width, nat_height;
			container.get_preferred_size (null, null, out nat_width, null);

			if (container.get_n_children () == 1)
				nat_width -= SPACING;

			container.get_preferred_size (null, null, null, out nat_height);

			wrapper.resize ((int) nat_width, (int) ((nat_height) +
				(settings.caption_visible ?
					(caption.height - (container.margin_bottom - caption.height))/2
					: 0)) );

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

			if (Settings.get_default ().animate)
				icon_fade (current, false);
			current = (WindowIcon) actor;

			update_indicator_position ();
		}

		void update_caption_text (bool initial = false) {

			var settings = Settings.get_default ();

			// FIXME: width contains incorrect value, if we have one children in container
			if (container.get_n_children () == 1 && container.width > settings.icon_size + SPACING) {
				GLib.Timeout.add (FIX_TIMEOUT_INTERVAL, () => {
					update_caption_text (initial);
					return false;
				}, GLib.Priority.DEFAULT);
				return;
			}

			if (initial) {
				caption.set_text ("");
				caption.set_position (0,
					container.y + container.height + INDICATOR_BORDER * 2);
				caption.visible = true;
				caption.save_easing_state ();
				caption.set_easing_duration (0);
				caption.restore_easing_state ();
			}

			if (settings.animate) {
				caption.save_easing_state ();
				caption.set_easing_duration (100);
		        caption.restore_easing_state ();
			}
	        caption.set_text (current.window.get_title ());

			if (settings.animate) {
	        	caption.save_easing_state ();
				caption.set_easing_duration (100);
				caption.x = wrapper.width/2 - caption.width/2;
	        	caption.restore_easing_state ();
			} else {
				caption.x = wrapper.width/2 - caption.width/2;
			}
		}

		void update_indicator_position (bool initial = false)
		{
			// FIXME there are some troubles with layouting, in some cases we
			//       are here too early, in which case all the children are at
			//       (0|0), so we can easily check for that and come back later
			if (container.get_n_children () > 1
				&& container.get_child_at_index (1).allocation.x1 < 1) {

				GLib.Timeout.add (FIX_TIMEOUT_INTERVAL, () => {
					update_indicator_position (initial);
					return false;
				}, GLib.Priority.DEFAULT);

				/*Idle.add (() => {
					update_indicator_position (initial);
					return false;
				});*/
				return;
			}

			float x, y;
			current.allocation.get_origin (out x, out y);

			if (current.opacity == Settings.get_default ().icon_opacity)
				icon_fade (current);

			if (initial) {
				indicator.visible = true;
				indicator.save_easing_state ();
				indicator.set_easing_duration (0);
			}

			indicator.x = container.margin_left +
			(container.get_n_children () > 1 ? x : 0) - INDICATOR_BORDER;
			indicator.y = container.margin_top + y - INDICATOR_BORDER;

			if (initial)
				indicator.restore_easing_state ();

			if (Settings.get_default ().caption_visible)
				update_caption_text (initial);
		}

		private void icon_fade (Actor act, bool _in=true) {
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
		name = "Elementary Alt Tab ver." + Gala.Plugins.ElementaryAltTab.SWITCHER_PLUGIN_VERSION,
		author = "Gala Developers, Popye",
		plugin_type = typeof (Gala.Plugins.ElementaryAltTab.Main),
		provides = Gala.PluginFunction.WINDOW_SWITCHER,
		load_priority = Gala.LoadPriority.IMMEDIATE
	};
}
