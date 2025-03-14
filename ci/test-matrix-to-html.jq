
def th($rowspan; $colspan):
	.[]
	| "      " + "<th"
		+ (if $rowspan > 1 then " rowspan=\"" + ($rowspan | tostring) + "\"" else "" end)
		+ (if $colspan > 1 then " colspan=\"" + ($colspan | tostring) + "\"" else "" end)
		+ ">"
		+ .
		+ "</th>"
;

def td($rowspan):
	.[]
	| "      " + "<td"
		+ (if $rowspan > 1 then " rowspan=\"" + ($rowspan | tostring) + "\"" else "" end)
		+ ">"
		+ .
		+ "</td>"
;

def build_os_list:
	$ARGS.named["build-os"] // ["fedora-rawhide"]
;

def os_grouping:
	{
	"fedora-": "Fedora",
	"centos-9-stream": "CentOS Stream 9",
	"almalinux-": "AlmaLinux",
	"rocky-": "Rocky Linux"
	}
;

def os_group:
	[
		.[] as $os
		| os_grouping
		| reduce keys[] as $k ([$os, "", $os]; if $os | startswith($k) then . = [$k, os_grouping[$k], $os[($k | length):]] end)
	]
	| reduce .[] as $r ([]; if $r[0] == .[-1][0] then .[-1][2] += [ $r[2] ] else . + [[ $r[0], $r[1], [ $r[2] ]]] end)
	|
	(
		.[]
		| . as $r
		| [.[1]]
		| th(if $r[2][0] == "" then 2 else 1 end; $r[2] | length)
	),
	"    </tr>",
	"    <tr>",
	(
		[ .[][2][] | select(. != "") ] | th(1; 1)
	)
;

(
.[0]
|
if $ARGS.named["job"] == "legend"
	then "---",
		"Legend: 🟢 — new image, compared to the one in registry; 🔷 — test is run with image that matches one in registry",
		halt
	else empty
end,
"## " + if $ARGS.named["job"] == "run"
		then "Test master + replica"
	else if $ARGS.named["job"] == "test-upgrade"
		then "Test upgrade from older installation"
	else if $ARGS.named["job"] == "k3s"
		then "Test in Kubernetes"
	end
	end
	end,
"<table>",
"  <thead>",
"    <tr>",
	if $ARGS.named["job"] == "run" then [ "Runtime", "Readonly", "External CA", "Volume", "Runs on Ubuntu" ] | th(2; 1) else empty end,
	if $ARGS.named["job"] == "test-upgrade" then [ "Runtime", "Runs on Ubuntu", "Upgrade from" ] | th(2; 1) else empty end,
	if $ARGS.named["job"] == "k3s" then [ "Kubernetes", "Runtime", "Runs on Ubuntu" ] | th(2; 1) else empty end,
	( build_os_list | os_group ),
"    </tr>",
"  </thead>",
"  <tbody>"
),

(
.[]["runs-on"]? |= if . == null then empty else sub("^ubuntu-"; "") end
| .[].readonly? |= if . == null then empty else if . == "--read-only" then "yes (ro)" else "rw" end end
| .[].ca? |= if . == null then empty else if . == "--external-ca" then "external" else "no" end end
| .[].volume? |= if . == null then empty else if . == "freeipa-data" then "volume" else "dir" end end
| sort_by(.runtime, .readonly, .ca, .volume, -(.["runs-on"] // 0 | tonumber), .["data-from"])
| reduce .[] as $row ({};
	if $ARGS.named["job"] == "run"
	then .[ $row.runtime ][ $row.readonly ][ $row.ca ][ $row.volume ][ $row["runs-on"] ][ $row.os ] = $row["fresh-image"]
	else if $ARGS.named["job"] == "test-upgrade"
	then .[ $row.runtime ][ $row["runs-on"] ][ $row[ "data-from" ] ][ $row.os ] = $row["fresh-image"]
	else if $ARGS.named["job"] == "k3s"
	then .k3s[ $row.runtime ][ $row["runs-on"] ][ $row.os ] = $row["fresh-image"]
	end
	end
	end
)
| walk(if type == "object" then .[".rowspan"] = ([ .[][".rowspan"]? ] | add // 1) else . end)
| . as $data
| [ path(.. | select(type == "object" and has(".rowspan"))) | select(length > 0)]
| (.[-1] | length) as $max
| foreach .[] as $i ([]; [$i, ($data | getpath($i)), (.[0] | length)])
| if (.[0] | length) == 1 or .[2] >= (.[0] | length) then "    <tr>" else empty end,

	(.[1][".rowspan"] as $rowspan | [ .[0][-1] ] | td($rowspan)),
	(
	if .[0] | length == $max then
		.[1] as $values
		| build_os_list[] as $os
		| [ if $values | has($os) then
			if $values[$os] then "🟢" else "🔷" end
			else "" end ] | td(1)
	else empty end
	),

if (.[0] | length) == $max then "    </tr>" else empty end
),

(
.[0]
|
"  </tbody>",
"</table>",
""
)

