
09:31:50.463 [error] GenServer #PID<0.691.0> terminating
** (Protocol.UndefinedError) protocol String.Chars not implemented for Tuple. This protocol is implemented for: Atom, BitString, Date, DateTime, Decimal, Float, Integer, List, Naiv
eDateTime, Phoenix.LiveComponent.CID, Postgrex.Copy, Postgrex.Query, Time, URI, Version, Version.Requirement

Got value:

    {:array, :string}

    (elixir 1.19.5) lib/string/chars.ex:7: String.Chars.impl_for!/1
    (elixir 1.19.5) lib/string/chars.ex:26: String.Chars.to_string/1
    (aludel 0.1.10) lib/aludel/web/components/core_components.ex:575: anonymous fn/2 in Aludel.Web.CoreComponents.translate_error/1
    (elixir 1.19.5) lib/enum.ex:2520: Enum."-reduce/3-lists^foldl/2-0-"/3
    (elixir 1.19.5) lib/enum.ex:1688: Enum."-map/2-lists^map/1-1-"/2
    (aludel 0.1.10) lib/aludel/web/components/core_components.ex:181: Aludel.Web.CoreComponents."input (overridable 1)"/1
    (phoenix_live_view 1.1.27) lib/phoenix_live_view/tag_engine.ex:137: Phoenix.LiveView.TagEngine.component/3
    (aludel 0.1.10) lib/aludel/web/live/prompt_live/new.html.heex:26: anonymous fn/3 in Aludel.Web.PromptLive.New.render/1
Process Label: {Phoenix.LiveView, Aludel.Web.PromptLive.New, "lv:phx-GKGeaLqyk7uBaQAH"}
Last message: %Phoenix.Socket.Message{topic: "lv:phx-GKGeaLqyk7uBaQAH", event: "event", payload: %{"event" => "validate", "meta" => %{"_target" => "prompt[name]"}, "type" => "form"
, "uploads" => %{}, "value" => "prompt%5Bname%5D=some+prompt&prompt%5Bdescription%5D=some+description&prompt%5Btags%5D=tag1&prompt%5B_unused_project_id%5D=&prompt%5Bproject_id%5D=&
prompt%5B_unused_template%5D=&prompt%5Btemplate%5D="}, ref: "43", join_ref: "42"}
State: %{socket: #Phoenix.LiveView.Socket<id: "phx-GKGeaLqyk7uBaQAH", endpoint: AludelDash.Endpoint, view: Aludel.Web.PromptLive.New, parent_pid: nil, root_pid: #PID<0.691.0>, rout
er: AludelDash.Router, assigns: %{access: :all, user: nil, prefix: "/", form: %Phoenix.HTML.Form{source: #Ecto.Changeset<action: nil, changes: %{}, errors: [name: {"can't be blank"
, [validation: :required]}], data: #Aludel.Prompts.Prompt<>, valid?: false, ...>, impl: Phoenix.HTML.FormData.Ecto.Changeset, id: "prompt", name: "prompt", data: %Aludel.Prompts.Pr
ompt{__meta__: #Ecto.Schema.Metadata<:built, "prompts">, id: nil, name: nil, description: nil, tags: [], project_id: nil, project: #Ecto.Association.NotLoaded<association :project 
is not loaded>, versions: #Ecto.Association.NotLoaded<association :versions is not loaded>, inserted_at: nil, updated_at: nil}, action: nil, hidden: [], params: %{}, errors: [], op
tions: [method: "post"], index: nil}, resolver: AludelDash.Resolver, prompt: %Aludel.Prompts.Prompt{__meta__: #Ecto.Schema.Metadata<:built, "prompts">, id: nil, name: nil, descript
ion: nil, tags: [], project_id: nil, project: #Ecto.Association.NotLoaded<association :project is not loaded>, versions: #Ecto.Association.NotLoaded<association :versions is not lo
aded>, inserted_at: nil, updated_at: nil}, variables: [], refresh: 5, current_path: "/prompts/new", __changed__: %{}, live_transport: "websocket", live_path: "/live", page_title: "
New Prompt", flash: %{}, live_action: :new, projects: [], aludel_name: nil, logo_path: nil, csp_nonces: %{script: nil, style: nil, img: nil}}, transport_pid: #PID<0.689.0>, sticky?
: false, ...>, components: {%{}, %{}, 1}, topic: "lv:phx-GKGeaLqyk7uBaQAH", serializer: Phoenix.Socket.V2.JSONSerializer, join_ref: "42", fingerprints: {988052894328965605334414704
42130450970, %{0 => {8610893936261560839021346933243383361, %{0 => {63679635126138757379818860769186642690, %{2 => {37861567072591995371659552835932069615, %{}}}}, 1 => {6367963512
6138757379818860769186642690, %{2 => {41505881134667015384729389926237039371, %{}}}}, 2 => {63679635126138757379818860769186642690, %{2 => {129170697175749181168782837443607826499,
 %{}}}}, 3 => {63679635126138757379818860769186642690, %{2 => {41470814941254401578307769559402441632, %{}}}}, 4 => {105761412502101622728505155926992569970, %{1 => {13499930246177
8737648730156019546381957, %{}}, 3 => {134999302461778737648730156019546381957, %{}}, 5 => {134999302461778737648730156019546381957, %{}}}}, 5 => {189150046852745646852305986050106
115412, %{0 => {266583467248160237114762821479468096542, %{1 => {12237894823794108423325714069324495489, %{3 => {85431297038753660090442055619009095328, %{0 => {1723398655240978227
64051956426777052795, %{}}, 1 => {57391940902906138717053847605954839464, %{}}, 2 => {172339865524097822764051956426777052795, %{}}, 3 => {325054263611515242522901550618625400247, 
%{6 => {314393564196024241637324801561988266021, %{}}}}, 4 => {57391940902906138717053847605954839464, %{}}, 7 => {206636682030808828279469435194978827513, %{3 => {1684268949821777
78346816370606305831406, %{}}}}}}}}}}}}, 6 => {178813308501384891745023266978824079288, %{1 => {78717018465828793838361031872953780252, %{}}, 2 => {78717018465828793838361031872953
780252, %{}}, 3 => {78717018465828793838361031872953780252, %{0 => {179809266246004421147136342693604504091, ...}}}, ...}}}}}}, ...}
