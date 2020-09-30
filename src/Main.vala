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

	public const string SWITCHER_PLUGIN_VERSION="0.2";

	public class Main : Gala.Plugin
	{
		const int MIN_OFFSET = 64;
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

		WindowIcon? cur_icon = null;
		WindowPreviewActor? cur_wpa = null;
		DesktopPreviewActor? cur_desktop = null;

		public override void initialize (Gala.WindowManager wm)
		{
			this.wm = wm;
			var settings = Settings.get_default ();

			KeyBinding.set_custom_handler ("switch-applications", (Meta.KeyHandlerFunc) handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-applications-backward", (Meta.KeyHandlerFunc) handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows", (Meta.KeyHandlerFunc) handle_switch_windows);
			KeyBinding.set_custom_handler ("switch-windows-backward", (Meta.KeyHandlerFunc) handle_switch_windows);

			var layout = new FlowLayout (FlowOrientation.HORIZONTAL);

			wrapper = new RoundedActor (Color.from_string (settings.wrapper_background_color),
				settings.wrapper_round_radius, settings.wrapper_stroke_width, Color.from_string (settings.wrapper_stroke_color));
			wrapper.reactive = true;
			wrapper.set_pivot_point (0.5f, 0.5f);
			wrapper.key_release_event.connect (key_release_event);
			wrapper.key_focus_out.connect (key_focus_out);

			container = new Actor ();
			container.layout_manager = layout;
			container.reactive = true;
			container.button_press_event.connect (container_mouse_press);
			container.motion_event.connect (container_motion_event);

			indicator = new RoundedActor (Color.from_string (settings.indicator_background_color), settings.indicator_round_radius,
				settings.indicator_stroke_width, Color.from_string (settings.indicator_stroke_color));

			indicator.margin_left = indicator.margin_top =
				indicator.margin_right = indicator.margin_bottom = 0;
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

				//FIXME: showing animation not work correctly for preview_in_switcher
				if (settings.preview_in_switcher)
					GLib.Timeout.add (0, () => {
						open_switcher ();
						update_indicator_position (true);
						return false;
					});
				else {
					open_switcher ();
					update_indicator_position (true);
				}
			}

			var binding_name = binding.get_name ();
			var backward = binding_name.has_suffix ("-backward");

			// FIXME for unknown reasons, switch-applications-backward won't be emitted, so we
			//       test manually if shift is held down
			/*
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

			//update wnck
			Wnck.Screen.get_default ().force_update ();

			foreach (var window in windows) {

				if (!settings.preview_in_switcher) {
					var icon = new WindowIcon (window, settings.icon_size);
					if (window == current_window)
						cur_icon = icon;
					else if (settings.animate)
						icon.opacity = settings.icon_opacity;
					icon.set_pivot_point (0.5f, 0.5f);
		            icon.set_easing_duration (200);
					container.add_child (icon);

					if (settings.animate)
						icon.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
				} else {
					var wpa = new WindowPreviewActor (window);
					container.add_child (wpa);
					if (window == current_window)
						cur_wpa = wpa;
					else if (settings.animate)
						wpa.opacity = settings.icon_opacity;

					if (settings.animate)
					wpa.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
				}
			}

			if (settings.desktop_in_switcher) {
				DesktopPreviewActor dpa = new DesktopPreviewActor ();
				if (settings.animate)
					dpa.opacity = settings.icon_opacity;
				container.add_child (dpa);

				if (settings.animate)
					dpa.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
			}
		}

		void open_switcher ()
		{
			var settings = Settings.get_default ();

			if (container.get_n_children () == 0) {
				return;
			} else if (container.get_n_children () == 1) {
				if ((cur_icon == null && cur_wpa == null) || settings.desktop_in_switcher)
					return;

				var window = (settings.preview_in_switcher ? cur_wpa.window : cur_icon.window);
				var workspace = wm.get_screen ().get_active_workspace ();

				if (!window.minimized && workspace == window.get_workspace ()) {
					return;
				}
			}

			if (opened)
				return;

			var screen = wm.get_screen ();

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
			indicator.set_easing_duration (settings.animate ? 200 : 0);

			container.margin_left = container.margin_top =
				container.margin_right = container.margin_bottom = settings.wrapper_padding;

			var l = container.layout_manager as FlowLayout;
			l.column_spacing = l.row_spacing = settings.wrapper_spacing;

			caption.renew_settings (
				Color.from_string (settings.caption_background_color),
				settings.caption_round_radius,
				settings.caption_stroke_width,
				Color.from_string (settings.caption_stroke_color),
				"%s %d".printf (settings.caption_font_name, settings.caption_font_size),
				Color.from_string (settings.caption_font_color)
			);

			indicator.visible = false;
			if (settings.preview_in_switcher)
				indicator.resize (settings.preview_width + settings.indicator_border * 2,
					settings.preview_height + settings.indicator_border * 2);
			else
				indicator.resize (settings.icon_size + settings.indicator_border * 2,
					settings.icon_size + settings.indicator_border * 2);
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
				nat_width -= settings.wrapper_spacing;

			container.get_preferred_size (null, null, null, out nat_height);

			wrapper.resize ((int) nat_width, (int) ((nat_height) +
				(settings.caption_visible ?
					(caption.height - (container.margin_bottom - caption.height))/2
					: 0)) );

			wrapper.set_position (geom.x + (geom.width - wrapper.width) / 2,
		                      	geom.y + (geom.height - wrapper.height) / 2);

			wm.ui_group.insert_child_above (wrapper, null);

			wrapper.save_easing_state ();
			wrapper.set_easing_duration (200);
			wrapper.set_scale (1, 1);
			wrapper.opacity = 255;
			wrapper.restore_easing_state ();

			modal_proxy = wm.push_modal ();
			modal_proxy.keybinding_filter = keybinding_filter;
			opened = true;

			wrapper.grab_key_focus ();

			// if we did not have the grab before the key was released, close immediately
			if ((get_current_modifiers () & modifier_mask) == 0)
				close_switcher (get_timestamp());
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

			var settings = Settings.get_default ();

			if (settings.animate) {
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

			if (settings.desktop_in_switcher && cur_desktop != null) {
				Utils.show_desktop (wm.get_screen ().get_active_workspace ());
			} else {
				var window = (settings.preview_in_switcher ? cur_wpa.window : cur_icon.window);

				if (window == null) {
					return;
				}

				var workspace = window.get_workspace ();
				if (workspace != wm.get_screen ().get_active_workspace ())
					workspace.activate_with_focus (window, time);
				else
					window.activate (time);
			}
		}

		void next_window (Display display, Workspace? workspace, bool backward)
		{
			Actor actor, current;
			var settings = Settings.get_default ();
			if (settings.desktop_in_switcher && cur_desktop != null)
				current = cur_desktop;
			else (settings.preview_in_switcher ? current = cur_wpa : current = cur_icon);
			if (!backward) {
				actor = current.get_next_sibling ();
				if (actor == null)
					actor = container.get_first_child ();
			} else {
				actor = current.get_previous_sibling ();
				if (actor == null)
					actor = container.get_last_child ();
			}

			if (settings.animate && current != actor) {
				Utils.icon_fade (current, false);
				current.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
			}

			if (settings.desktop_in_switcher && (actor as DesktopPreviewActor) != null)
				cur_desktop = (DesktopPreviewActor) actor;
			else {
				cur_desktop = null;
				if (settings.preview_in_switcher)
					cur_wpa = (WindowPreviewActor) actor;
				else cur_icon = (WindowIcon) actor;
			}

			update_indicator_position ();
		}

		void update_caption_text (bool initial = false) {

			var settings = Settings.get_default ();

			// FIXME: width contains incorrect value, if we have one children in container
			if (container.get_n_children () == 1 && container.width >
				(settings.preview_in_switcher ? settings.preview_width : settings.icon_size) + settings.wrapper_spacing) {
				GLib.Timeout.add (FIX_TIMEOUT_INTERVAL, () => {
					update_caption_text (initial);
					return false;
				}, GLib.Priority.DEFAULT);
				return;
			}

			var current_window = (settings.preview_in_switcher ? cur_wpa.window : cur_icon.window);
			var current_caption = "n/a";
			if (cur_desktop != null && settings.desktop_in_switcher) {
				current_caption = settings.desktop_display_name;
			} else if (current_window != null) {
				ulong xid = (ulong) current_window.get_xwindow ();
				var wnck_current_window = Wnck.Window.get (xid);
				if(wnck_current_window != null){
					current_caption = wnck_current_window.get_name ();
				} // else it will stay "n/a"
			}

			if (initial) {
				caption.set_text (current_caption);
				caption.set_position (wrapper.width/2 - caption.width/2,
					container.y + container.height + settings.indicator_border +
						settings.caption_top_magrin);
				caption.visible = true;
				if (settings.animate)
					caption.opacity = 100;
				caption.save_easing_state ();
				caption.set_easing_duration (200);
				caption.opacity = 255;
				caption.restore_easing_state ();
			}

			if (settings.animate) {
				caption.save_easing_state ();
				caption.set_easing_mode (AnimationMode.EASE_OUT_QUINT);
				caption.set_easing_duration (300);
		        caption.restore_easing_state ();
			}

        	caption.set_text (current_caption);

			if (settings.animate) {
	        	caption.save_easing_state ();
				caption.set_easing_mode (AnimationMode.EASE_OUT_QUINT);
				caption.set_easing_duration (300);
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
			var settings = Settings.get_default ();
			if (settings.desktop_in_switcher && cur_desktop != null) {
				cur_desktop.allocation.get_origin (out x, out y);
				if (settings.icon_opacity == cur_desktop.opacity)
					Utils.icon_fade (cur_desktop);
				cur_desktop.set_scale (settings.active_element_scale, settings.active_element_scale);
			}
			else if (settings.preview_in_switcher) {
				cur_wpa.allocation.get_origin (out x, out y);
				if (settings.icon_opacity == cur_wpa.opacity)
					Utils.icon_fade (cur_wpa);
				cur_wpa.set_scale (settings.active_element_scale, settings.active_element_scale);
			}
			else {
				cur_icon.allocation.get_origin (out x, out y);
				if (settings.icon_opacity == cur_icon.opacity)
					Utils.icon_fade (cur_icon);
				cur_icon.set_scale (settings.active_element_scale, settings.active_element_scale);
			}

			if (initial) {
				indicator.visible = true;
				indicator.save_easing_state ();
				indicator.set_easing_duration (0);
			}

			indicator.x = container.margin_left +
			(container.get_n_children () > 1 ? x : 0) - settings.indicator_border;
			indicator.y = container.margin_top + y - settings.indicator_border;

			if (initial)
				indicator.restore_easing_state ();

			if (settings.caption_visible)
				update_caption_text (initial);
		}

		private void close_window ()
		{
			var current_window = (Settings.get_default ().preview_in_switcher ? cur_wpa.window : cur_icon.window);
			if (current_window == null)
				return;
			var screen = current_window.get_screen ();
			current_window.@delete (get_timestamp());
			//collect_windows ();
		}

		void key_focus_out ()
		{
			if (opened) {
				//FIXME: problem if layout swicher across witch window switcher shortcut
				close_switcher (get_timestamp());
			}
		}

		bool container_motion_event (MotionEvent event)
		{
			var actor = event.stage.get_actor_at_pos (PickMode.ALL, (int) event.x, (int) event.y);
			if (actor == null)
				return true;
			var settings = Settings.get_default ();

			if (settings.desktop_in_switcher) {
				var selected_desktop = actor as DesktopPreviewActor;
				if (selected_desktop == null)
					selected_desktop = actor.get_parent ().get_parent () as DesktopPreviewActor;
				if (selected_desktop == null && settings.preview_in_switcher && (actor as DesktopIcon) != null)
					selected_desktop = actor.get_parent () as DesktopPreviewActor;
				if (selected_desktop != null) {
					if (cur_desktop != null)
						return true;
					cur_desktop = selected_desktop;
					if (settings.animate) {
						Actor cur_actor;
						if (cur_icon != null)
							cur_actor = cur_icon;
						else
							cur_actor = cur_wpa;
						Utils.icon_fade (cur_actor, false);
						cur_actor.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
					}
					update_indicator_position ();
					return true;
				}
			}

			if (settings.preview_in_switcher) {
				var selected = actor as WindowPreviewActor;
				if (selected == null) {
					// FIXME: nested actors do not track parent motion signal
					if ((actor as WindowIcon) != null )
						selected = actor.get_parent () as WindowPreviewActor;
					else if ((actor.get_first_child () as Clone) != null)
						selected = actor.get_parent () as WindowPreviewActor;
				}

				if (selected == null)
					return true;

				if (cur_wpa != selected || cur_desktop != null) {
					if (cur_desktop != null) {
						if (settings.animate) {
							Utils.icon_fade (cur_desktop, false);
							cur_desktop.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
						}
						cur_desktop = null;
					}

					if (settings.animate) {
						Utils.icon_fade (cur_wpa, false);
						cur_wpa.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
					}
					cur_wpa = selected;
					update_indicator_position ();
				}
			} else {
				var selected = actor as WindowIcon;
				if (selected == null)
					return true;

				if (cur_icon != selected || cur_desktop != null) {
					if (cur_desktop != null) {
						if (settings.animate) {
							Utils.icon_fade (cur_desktop, false);
							cur_desktop.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
						}
						cur_desktop = null;
					}

					if (settings.animate) {
						Utils.icon_fade (cur_icon, false);
						cur_icon.set_scale (settings.inactive_element_scale, settings.inactive_element_scale);
					}
					cur_icon = selected;
					update_indicator_position ();
				}
			}

			return true;
		}

		bool container_mouse_press (ButtonEvent event)
		{
			if (opened && event.button == Gdk.BUTTON_PRIMARY)
				close_switcher (event.time);
			//else if (opened && event.button == Gdk.BUTTON_MIDDLE)
				//close_window ();

			return true;
		}

		bool key_release_event (KeyEvent event)
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
			// if it's not built-in, we can block it right away
			if (!binding.is_builtin ())
				return true;

			// otherwise we determine by name if it's meant for us
			var name = binding.get_name ();


			return !(name == "switch-applications" || name == "switch-applications-backward"
				|| name == "switch-windows" || name == "switch-windows-backward");
		}

		private uint32 get_timestamp(){
			var screen = wm.get_screen ();
			return screen.get_display ().get_current_time ();
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
