This is a web application written using the Phoenix web framework.

This local file contains only project-specific guidance and avoids repeating general engineering standards that may already be documented elsewhere.

## Phoenix project specifics

- Use `mix precommit` when you are done and fix any pending issues.
- The PR description must use `.github/PULL_REQUEST_TEMPLATE.md`.

### Phoenix v1.8 details

- `MyAppWeb.Layouts` is already aliased through `my_app_web.ex`; do not add another alias just to use `<Layouts.app>`.
- If you hit a missing `current_scope` assign, fix the route placement and `live_session` wiring rather than working around it.
- `<.flash_group>` may only be used in `layouts.ex`.
- If you override `<.input>` classes, you are replacing the defaults entirely and must fully style the input yourself.

### JS and CSS details

- Tailwind v4 import syntax in `assets/css/app.css` must remain:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- Only the `app.js` and `app.css` bundles are supported.
- Do not reference external script or stylesheet tags directly from layouts; import dependencies through the supported bundles.

### Phoenix HTML and HEEx details

- Add explicit DOM IDs to key interactive elements so LiveView tests can target them reliably.
- Use HEEx comment syntax: `<%!-- comment --%>`.
- For literal `{` and `}` inside code examples, annotate the parent with `phx-no-curly-interpolation`.
- For class attributes with multiple values or conditions, always use HEEx list syntax.
- Do not use `<% Enum.each %>` in templates; use `<%= for ... do %>`.
- Inside attributes, use `{...}` interpolation, not `<%= ... %>`.

### LiveView details

- Prefer avoiding `LiveComponent`s unless there is a specific reason.
- If a `phx-hook` manages its own DOM, pair it with `phx-update="ignore"`.
- Keep hooks and JavaScript in `assets/js`; never embed `<script>` tags in HEEx.

### LiveView streams

- Use streams only for collections.
- When using streams, set `phx-update="stream"` on the parent and use the streamed DOM id for each child.
- Streams are not enumerable; to filter or refresh them, refetch and restream with `reset: true`.
- Track counts and empty states separately; streams do not provide that directly.

### LiveView testing

- Prefer `Phoenix.LiveViewTest` selectors and helpers like `element/2` and `has_element?/2` over raw HTML assertions when possible.
- Favor asserting on stable elements and outcomes over copy text.
- If selector debugging is needed, use `LazyHTML` to inspect a narrow fragment.

### Form handling

- Drive forms from `to_form/2` assigns in the LiveView.
- In templates, use `<.form for={@form} ...>` and fields like `@form[:field]`.
- Do not access changesets directly from templates.
- Do not use `<.form let={f} ...>`; use the assigned form instead.
