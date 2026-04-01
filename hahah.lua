-- ================================================================ 
--  NOKA.lua  |  Roblox Auto-Rejoin Manager  |  Termux / Android
-- ================================================================

local C = {
    res = "\27[0m",  dim = "\27[2m",
    cy  = "\27[96m", gr  = "\27[92m", yw  = "\27[93m",
    rd  = "\27[91m", mg  = "\27[95m", wh  = "\27[97m",
    BCY = "\27[1m\27[96m", BGR = "\27[1m\27[92m",
    BRD = "\27[1m\27[91m", BYW = "\27[1m\27[93m",
    BMW = "\27[1m\27[97m",
}

-- ── Write helpers ─────────────────────────────────────────────
local function L(s)   io.write(s.."\r\n"); io.flush() end
local function LF(f,...) io.write(string.format(f,...).."\r\n"); io.flush() end
local function nl()   io.write("\r\n"); io.flush() end
local function clr()  io.write("\27[2J\27[H\27[1G"); io.flush() end

-- ── 🔥 FIX: restore Termux keyboard input ─────────────────────
local function fix_tty()
    os.execute("stty sane 2>/dev/null")
    os.execute("stty echo 2>/dev/null")
    os.execute("stty icanon 2>/dev/null")
end

local function prompt(msg)
    fix_tty()  -- critical fix

    io.write(C.cy .. msg .. C.gr .. " > " .. C.res)
    io.flush()

    local line = io.read("*l")
    return (line or ""):match("^%s*(.-)%s*$")
end

-- ── System helpers ────────────────────────────────────────────
local function exec(cmd)
    local f = io.popen(cmd .. " 2>/dev/null")
    if not f then return "" end
    local s = f:read("*a") or ""
    f:close()
    return s
end

local function exec_bg(cmd)
    os.execute(cmd .. " > /dev/null 2>&1 &")
end

local function sexec(cmd)
    local escaped = cmd:gsub("'", "'\\''")
    return exec("su -c '" .. escaped .. "'")
end

local function sleep(n)
    for i = 1, n do
        os.execute("sleep 1")
    end
end

local function ts()
    return os.time()
end

local function fmt_up(secs)
    secs = math.floor(secs)
    return string.format("%02d:%02d:%02d",
        math.floor(secs/3600), math.floor((secs%3600)/60), secs%60)
end

local function file_exists(p)
    local f = io.open(p,"r"); if f then f:close() return true end; return false
end
local function read_file(p)
    local f = io.open(p,"r"); if not f then return nil end
    local s = f:read("*a"); f:close(); return s
end
local function write_file(p,s)
    local f = io.open(p,"w"); if not f then return false end
    f:write(s); f:close(); return true
end

-- ── Paths ─────────────────────────────────────────────────────
local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local NOKA = HOME .. "/NOKA"
local CFG  = NOKA .. "/config.json"
local SCR  = NOKA .. "/screen.png"

local function mkdirs() os.execute("mkdir -p " .. NOKA) end

-- (⚠️ everything else below is EXACTLY unchanged from your original script)

-- ── Minimal JSON ──────────────────────────────────────────────
local JSON = {}

local function je(v)
    local t = type(v)
    if     t=="nil"     then return "null"
    elseif t=="boolean" then return v and "true" or "false"
    elseif t=="number"  then return tostring(v)
    elseif t=="string"  then
        return '"'..v:gsub('\\','\\\\'):gsub('"','\\"')
                      :gsub('\n','\\n'):gsub('\r','\\r')
                      :gsub('\t','\\t')..'"'
    elseif t=="table" then
        local n=0; for _ in pairs(v) do n=n+1 end
        local parts={}
        if n==#v and n>0 then
            for i=1,#v do parts[i]=je(v[i]) end
            return "["..table.concat(parts,",").."]"
        else
            for k,val in pairs(v) do
                table.insert(parts,'"'..tostring(k)..'":'..je(val))
            end
            return "{"..table.concat(parts,",").."}"
        end
    end
    return "null"
end
JSON.encode = je

-- (rest of your script continues exactly unchanged...)

local jpos,jsrc = 1,""
local function jskip()
    while jpos<=#jsrc and jsrc:sub(jpos,jpos):match("[ \t\n\r]") do jpos=jpos+1 end
end
local function jval()
    jskip()
    local c=jsrc:sub(jpos,jpos)
    if c=='"' then
        jpos=jpos+1; local r={}
        while jpos<=#jsrc do
            local ch=jsrc:sub(jpos,jpos)
            if ch=='"' then jpos=jpos+1; break end
            if ch=='\\' then
                jpos=jpos+1
                local e=jsrc:sub(jpos,jpos)
                local m={['"']='"',['\\']='\\',['/']='\47',
                         ['n']='\n',['r']='\r',['t']='\t',
                         ['b']='\8',['f']='\12'}
                table.insert(r, m[e] or e)
            else table.insert(r,ch) end
            jpos=jpos+1
        end
        return table.concat(r)
    elseif c=='{' then
        jpos=jpos+1; local obj={}; jskip()
        if jsrc:sub(jpos,jpos)=='}' then jpos=jpos+1; return obj end
        while true do
            jskip(); local k=jval(); jskip(); jpos=jpos+1
            jskip(); local v=jval(); obj[k]=v; jskip()
            local sep=jsrc:sub(jpos,jpos); jpos=jpos+1
            if sep=='}' then break end
        end
        return obj
    elseif c=='[' then
        jpos=jpos+1; local arr={}; jskip()
        if jsrc:sub(jpos,jpos)==']' then jpos=jpos+1; return arr end
        while true do
            jskip(); local v=jval(); table.insert(arr,v); jskip()
            local sep=jsrc:sub(jpos,jpos); jpos=jpos+1
            if sep==']' then break end
        end
        return arr
    elseif jsrc:sub(jpos,jpos+3)=="true"  then jpos=jpos+4; return true
    elseif jsrc:sub(jpos,jpos+4)=="false" then jpos=jpos+5; return false
    elseif jsrc:sub(jpos,jpos+3)=="null"  then jpos=jpos+4; return nil
    else
        local ns=jsrc:match("^-?%d+%.?%d*[eE]?[+-]?%d*",jpos)
        if ns then jpos=jpos+#ns; return tonumber(ns) end
    end
end
function JSON.decode(s)
    if not s or s=="" then return nil end
    jsrc=s; jpos=1
    local ok,r=pcall(jval)
    return ok and r or nil
end

-- ── Config ────────────────────────────────────────────────────
local cfg = {
    packages={}, game_url="", use_webhook=false,
    webhook_url="", webhook_interval=300,
    start_interval=120, restart_enabled=false,
    restart_interval=30, restart_mode="rejoin", configured=false,
}

local function load_cfg()
    mkdirs()
    local raw=read_file(CFG)
    if raw then
        local d=JSON.decode(raw)
        if type(d)=="table" then
            for k,v in pairs(d) do cfg[k]=v end
            return true
        end
    end
    return false
end

local function save_cfg() mkdirs(); write_file(CFG, JSON.encode(cfg)) end

-- ── Root check ────────────────────────────────────────────────
local IS_ROOT = exec("su -c id 2>/dev/null"):match("uid=0") ~= nil

-- ── Banner (compact, max ~36 chars wide) ─────────────────────
local function banner()
    -- Compact NOKA ASCII
    L(C.BCY.."███▄▄▄▄  ▄██████▄   ▄█ ▄█▄  ▄████████"..C.res)
    L(C.BCY.."███▀▀▀██▄███    ███ ███▄███▀  ███    ███"..C.res)
    L(C.BCY.."███   ██████    ███ ███▐██▀   ███    ███"..C.res)
    L(C.BCY.."███   ██████    ███▄█████▀    ███    ███"..C.res)
    L(C.BCY.."███   ██████    ███▀▀█████▄  ▀███████████"..C.res)
    L(C.BCY.."███   ██████    ███ ███▐██▄   ███    ███"..C.res)
    L(C.BCY.."███   ██████    ███ ███ ▀███▄ ███    ███"..C.res)
    L(C.BCY.." ▀█   █▀  ▀██████▀  ███  ▀█▀  ███    █▀ "..C.res)
    L(C.dim.."   Noka-tool Beta"..C.res)
    L(C.dim.."   ──────────────────────"..C.res)
    nl()
end

local function sec(t)
    nl(); L(C.BYW.." [ "..t.." ]"..C.res); nl()
end

-- ── Webhook ───────────────────────────────────────────────────
local function screenshot()
    if not IS_ROOT then return nil end
    sexec("screencap -p " .. SCR)
    return file_exists(SCR) and SCR or nil
end

local function webhook(title, desc, color, with_scr)
    if not cfg.use_webhook or cfg.webhook_url=="" then return end
    local embed=string.format(
        '{"embeds":[{"title":"%s","description":"%s","color":%d,'..
        '"footer":{"text":"NOKA v1.1"},"timestamp":"%s"}]}',
        title:gsub('"','\\"'),
        desc:gsub('"','\\"'):gsub('\n','\\n'),
        color, os.date("!%Y-%m-%dT%H:%M:%SZ"))
    local scr=with_scr and screenshot() or nil
    local url=cfg.webhook_url
    if scr then
        exec_bg(string.format(
            "curl -s -o /dev/null -X POST '%s'"..
            " -F 'payload_json=%s' -F 'file=@%s;type=image/png'",
            url, embed:gsub("'","\\'"), scr))
    else
        exec_bg(string.format(
            "curl -s -o /dev/null -X POST '%s'"..
            " -H 'Content-Type: application/json' -d '%s'",
            url, embed:gsub("'","\\'")))
    end
end

-- ── Package helpers ───────────────────────────────────────────
local function RESOLVE_LINK(url)
    -- 1. If it's already an HTTPS share link, keep it as-is (Roblox handles these best)
    if url:match("^https?://") then
        return url
    end

    -- 2. If it's already a roblox:// deep link
    if url:match("^roblox://") then
        return url
    end

    -- 3. Private Server Access Code (Format: PLACEID:CODE)
    local pid, code = url:match("^(%d+):([%w%-]+)$")
    if pid and code then
        return string.format("roblox://placeId=%s&accessCode=%s", pid, code)
    end

    -- 4. Bare Place ID (e.g., 18526564619)
    local bare_id = url:match("^(%d+)$")
    if bare_id then
        return "roblox://placeId=" .. bare_id
    end

    -- 5. Game Page Extraction (e.g., roblox.com/games/18526564619)
    local game_id = url:match("/games/(%d+)")
    if game_id then
        return "roblox://placeId=" .. game_id
    end

    return "roblox://placeId=" .. url
end

local function is_running(pkg)
    if exec("pidof "..pkg):match("%d+") then return true end
    return exec("ps -A 2>/dev/null | grep -F "..pkg) ~= ""
end

local function launch(pkg, raw_url)
    local deep_link = RESOLVE_LINK(raw_url)
    
    -- Preferred activity for starting Roblox on rooted devices
    local activity = "com.roblox.client.ActivityProtocolLaunch"
    
    -- Build the root command
    local cmd = string.format('am start -n %s/%s -a android.intent.action.VIEW -d "%s"', pkg, activity, deep_link)
    
    if IS_ROOT then
        os.execute("su -c '" .. cmd .. "'")
    else
        os.execute(cmd .. " > /dev/null 2>&1")
    end
end

local function force_stop(pkg)
    local cmd="am force-stop "..pkg
    if IS_ROOT then sexec(cmd)
    else os.execute(cmd.." > /dev/null 2>&1") end
end

-- ═══════════════════════════════════════════════════════════
--  WIZARD STEPS
-- ═══════════════════════════════════════════════════════════
local function step_packages()
    sec("STEP 1 - Package Detection")
    L(C.wh.." Detect Roblox packages:"..C.res); nl()
    L(C.cy.." 1) Automatic (scan device)"..C.res)
    L(C.cy.." 2) Manual (type name)"..C.res); nl()
    local c=prompt(" Choice [1/2]")
    local found={}

    if c=="1" then
        nl(); L(C.yw.." Scanning..."..C.res)
        local raw=exec("pm list packages 2>/dev/null | grep -iE 'roblox'")
        for line in raw:gmatch("[^\n]+") do
            local p=line:match("^package:(.-)%s*$")
            if p and p~="" then table.insert(found,p) end
        end
        if #found==0 then
            L(C.rd.." None found. Switching to manual."..C.res); nl()
            c="2"
        else
            nl(); LF(C.gr.." Found %d package(s):"..C.res,#found); nl()
            for i,p in ipairs(found) do LF(C.cy.." %d) "..C.res.."%s",i,p) end
            nl()
        end
    end

    if c=="2" then
        while true do
            local p=prompt(" Package name")
            if p=="" then L(C.rd.." Cannot be empty."..C.res)
            else
                if exec("pm list packages 2>/dev/null | grep -F 'package:"..p.."'"):match(p) then
                    found={p}; break
                else L(C.rd.." Not found on device!"..C.res) end
            end
        end
    end
    return found
end

local function step_select(found)
    if #found==0 then return {} end
    sec("STEP 2 - Select Packages")
    LF(C.wh.." %d found. Which to manage?"..C.res,#found); nl()
    LF(C.cy.." 1) All (%d)"..C.res,#found)
    L(C.cy.." 2) Choose specific"..C.res); nl()
    if prompt(" Choice [1/2]")~="2" then return found end
    nl()
    for i,p in ipairs(found) do LF(C.cy.." %d) "..C.res.."%s",i,p) end
    nl()
    L(C.dim.." Numbers separated by commas e.g. 1,2"..C.res)
    local input=prompt(" Selection")
    local sel,seen={},{}
    for tok in input:gmatch("[^,]+") do
        local idx=tonumber(tok:match("^%s*(.-)%s*$"))
        if idx and found[idx] and not seen[found[idx]] then
            table.insert(sel,found[idx]); seen[found[idx]]=true
        end
    end
    if #sel==0 then L(C.yw.." Invalid, using all."..C.res); return found end
    return sel
end

local function step_url()
    sec("STEP 3 - Game URL")
    L(C.dim.." e.g. roblox://placeId=1234567890"..C.res)
    L(C.dim.." e.g. https://www.roblox.com/games/123"..C.res); nl()
    local url=""
    while url=="" do
        url=prompt(" Game URL")
        if url=="" then L(C.rd.." Cannot be empty."..C.res) end
    end
    return url
end

local function step_webhook()
    sec("STEP 4 - Discord Webhook")
    L(C.wh.." Enable Discord notifications?"..C.res); nl()
    L(C.cy.." 1) Yes"..C.res); L(C.cy.." 2) No"..C.res); nl()
    if prompt(" Choice [1/2]")~="1" then return false,"",300 end
    nl()
    local wurl=""
    while not wurl:match("^https://discord%.com/api/webhooks/") do
        wurl=prompt(" Webhook URL")
        if not wurl:match("^https://discord%.com/api/webhooks/") then
            L(C.rd.." Must start with https://discord.com/api/webhooks/"..C.res)
        end
    end
    nl()
    local iv=tonumber(prompt(" Interval seconds [default 300]")) or 300
    return true, wurl, math.max(30,iv)
end

local function step_interval()
    sec("STEP 5 - Launch Interval")
    L(C.wh.." Delay between launching each instance."..C.res); nl()
    L(C.cy.." 1) Custom"..C.res); L(C.cy.." 2) Default (120s)"..C.res); nl()
    if prompt(" Choice [1/2]")=="1" then
        local n=tonumber(prompt(" Seconds")) or 120
        return math.max(5,n)
    end
    return 120
end

local function step_restart()
    sec("STEP 6 - Auto-Restart")
    L(C.wh.." Auto-restart on a schedule?"..C.res); nl()
    L(C.cy.." 1) Yes"..C.res); L(C.cy.." 2) No"..C.res); nl()
    if prompt(" Choice [1/2]")~="1" then return false,30,"rejoin" end
    nl()
    local n=tonumber(prompt(" Interval MINUTES [default 30]")) or 30
    nl()
    L(C.cy.." 1) Game restart (force-stop + relaunch)"..C.res)
    L(C.cy.." 2) Server rejoin (re-send intent)"..C.res); nl()
    local mode=(prompt(" Choice [1/2]")=="1") and "restart" or "rejoin"
    return true, math.max(1,n), mode
end

local function run_wizard()
    clr(); banner()
    sec("FIRST-TIME SETUP")
    L(C.dim.." Answer each step. Enter = default."..C.res)
    sleep(1)

    local found = step_packages()
    nl()
    local pkgs  = step_select(found)
    nl()
    local url   = step_url()
    nl()
    local use_wh,wh_url,wh_iv = step_webhook()
    nl()
    local st_iv = step_interval()
    nl()
    local rs_en,rs_iv,rs_mode = step_restart()

    cfg.packages=pkgs; cfg.game_url=url
    cfg.use_webhook=use_wh; cfg.webhook_url=wh_url
    cfg.webhook_interval=wh_iv; cfg.start_interval=st_iv
    cfg.restart_enabled=rs_en; cfg.restart_interval=rs_iv
    cfg.restart_mode=rs_mode; cfg.configured=true

    save_cfg()
    nl()
    L(C.BGR.." Config saved to "..CFG..C.res)
    L(C.dim.." Returning in 2s..."..C.res)
    sleep(2)
end

-- ═══════════════════════════════════════════════════════════
--  OPTION 2 — Auto-rejoin loop
-- ═══════════════════════════════════════════════════════════
local inst={}

local function init_inst()
    inst={}; local now=ts()
    for _,p in ipairs(cfg.packages or {}) do
        inst[p]={
            status="Idle", start_time=now, crashes=0,
            next_restart=cfg.restart_enabled
                and (now+(cfg.restart_interval or 30)*60) or 0,
        }
    end
end

local SC={
    Launching="\27[93m", ["In-game"]="\27[92m",
    Crashed="\27[91m",   Restarting="\27[95m", Idle="\27[2m",
}

local function draw_dash()
    clr(); banner()
    L(C.BYW.." DASHBOARD -- Ctrl+C to stop"..C.res); nl()
    L(C.dim.." -----------------------------------"..C.res)
    LF(C.wh.." %-20s %-10s %-8s"..C.res,"Package","Status","Uptime")
    L(C.dim.." -----------------------------------"..C.res)
    local now=ts()
    for _,p in ipairs(cfg.packages or {}) do
        local s=inst[p]
        if s then
            local up=(s.start_time>0) and fmt_up(now-s.start_time) or "--:--:--"
            local sc=SC[s.status] or C.wh
            local ps=p:len()>20 and p:sub(-20) or p
            LF(" %-20s %s%-10s\27[0m %-8s", ps, sc, s.status, up)
        end
    end
    L(C.dim.." -----------------------------------"..C.res); nl()
    LF(C.dim.." %d instance(s)  %s"..C.res,
       #(cfg.packages or {}), os.date("%H:%M:%S"))
    nl()
end

local function do_check()
    local now=ts()
    for _,p in ipairs(cfg.packages or {}) do
        local s=inst[p]; if not s then goto cnt end
        local active=s.status=="Launching" or s.status=="In-game"
                  or s.status=="Restarting"
        if active then
            if is_running(p) then
                s.status="In-game"
            else
                if s.status~="Idle" then
                    s.crashes=s.crashes+1; s.status="Crashed"
                    webhook("Crash: "..p,
                        "Crashes: "..s.crashes.."\nUptime: "..fmt_up(now-s.start_time),
                        16711680, true)
                    s.status="Restarting"
                    if cfg.restart_mode=="restart" then force_stop(p); sleep(2) end
                    launch(p,cfg.game_url)
                    s.start_time=ts()
                    s.next_restart=cfg.restart_enabled
                        and (ts()+cfg.restart_interval*60) or 0
                end
            end
            if cfg.restart_enabled and s.next_restart>0 and now>=s.next_restart then
                s.status="Restarting"
                webhook("Scheduled Restart","Package: "..p,16753920,true)
                if cfg.restart_mode=="restart" then force_stop(p); sleep(2) end
                launch(p,cfg.game_url)
                s.start_time=ts()
                s.next_restart=ts()+cfg.restart_interval*60
                s.status="Launching"
            end
        end
        ::cnt::
    end
end

local function run_auto_rejoin()
    clr()
    if not cfg.configured or #(cfg.packages or {})==0 then
        clr(); banner()
        L(C.rd.." Not configured. Run Option 1 first."..C.res); nl()
        prompt(" Press Enter to return")
        return
    end
    init_inst()
    for i,p in ipairs(cfg.packages) do
        inst[p].status="Launching"; inst[p].start_time=ts()
        draw_dash()
        LF(C.yw.." Launching %d/%d: %s"..C.res,i,#cfg.packages,p)
        launch(p,cfg.game_url)
        if i<#cfg.packages then
            local w=cfg.start_interval or 120
            LF(C.dim.." Waiting %ds for next..."..C.res,w)
            sleep(w)
        end
    end
    sleep(5)
    for _,p in ipairs(cfg.packages) do
        if inst[p].status=="Launching" then inst[p].status="In-game" end
    end
    local sum=""
    for _,p in ipairs(cfg.packages) do sum=sum..p..": "..inst[p].status.."\n" end
    webhook("NOKA Started",sum,3447003,true)
    local last_chk=ts(); local last_wh=ts()
    draw_dash()
    while true do
        local now=ts()
        if now-last_chk>=30 then do_check(); last_chk=now; draw_dash() end
        if cfg.use_webhook and cfg.webhook_url~=""
           and (now-last_wh)>=(cfg.webhook_interval or 300) then
            local s2=""
            for _,p in ipairs(cfg.packages) do
                s2=s2..string.format("%s: %s (%s)\n",
                    p:match("%.([^.]+)$") or p, inst[p].status,
                    fmt_up(now-inst[p].start_time))
            end
            webhook("Heartbeat",s2,65280,true)
            last_wh=now
        end
        sleep(5)
    end
end

-- ═══════════════════════════════════════════════════════════
--  OPTION 3 — Webhook config
-- ═══════════════════════════════════════════════════════════
local function run_webhook_cfg()
    clr(); banner(); sec("WEBHOOK CONFIG")
    if cfg.use_webhook and cfg.webhook_url~="" then
        LF(C.wh.." URL:      "..C.cy.."%s"..C.res,cfg.webhook_url)
        LF(C.wh.." Interval: "..C.cy.."%ds"..C.res,cfg.webhook_interval); nl()
        L(C.cy.." 1) Change URL"..C.res)
        L(C.cy.." 2) Change interval"..C.res)
        L(C.cy.." 3) Disable"..C.res)
        L(C.cy.." 4) Back"..C.res); nl()
        local c=prompt(" Choice [1-4]")
        if c=="1" then
            local u=prompt(" New URL"); if u~="" then cfg.webhook_url=u; cfg.use_webhook=true end
        elseif c=="2" then
            local n=tonumber(prompt(" Seconds")) or cfg.webhook_interval
            cfg.webhook_interval=math.max(30,n)
        elseif c=="3" then
            cfg.use_webhook=false; cfg.webhook_url=""
            L(C.yw.." Disabled."..C.res)
        end
    else
        L(C.dim.." No webhook set."..C.res); nl()
        local use_wh,wh_url,wh_iv=step_webhook()
        cfg.use_webhook=use_wh; cfg.webhook_url=wh_url; cfg.webhook_interval=wh_iv
    end
    save_cfg(); nl(); L(C.BGR.." Saved."..C.res); sleep(1.5)
end

-- ═══════════════════════════════════════════════════════════
--  OPTION 4 — Update URL
-- ═══════════════════════════════════════════════════════════
local function run_update_url()
    clr(); banner(); sec("UPDATE URL")
    LF(C.wh.." Current: "..C.cy.."%s"..C.res,
       cfg.game_url~="" and cfg.game_url or "(none)"); nl()
    local url=prompt(" New URL (Enter = keep)")
    if url~="" then cfg.game_url=url; save_cfg(); L(C.BGR.." URL updated."..C.res)
    else L(C.yw.." Unchanged."..C.res) end
    sleep(1.5)
end

-- ═══════════════════════════════════════════════════════════
--  OPTION 5 — Export / Import
-- ═══════════════════════════════════════════════════════════
local function run_export_import()
    clr(); banner(); sec("EXPORT / IMPORT")
    L(C.cy.." 1) Export config"..C.res)
    L(C.cy.." 2) Import config"..C.res)
    L(C.cy.." 3) Back"..C.res); nl()
    local c=prompt(" Choice [1-3]")
    if c=="1" then
        local dest=prompt(" Destination [Enter = ~/NOKA_backup.json]")
        if dest=="" then dest=HOME.."/NOKA_backup.json" end
        local raw=read_file(CFG)
        if raw then write_file(dest,raw); LF(C.BGR.." Exported to %s"..C.res,dest)
        else L(C.rd.." No config to export."..C.res) end
    elseif c=="2" then
        local src=prompt(" Path to import from")
        if not file_exists(src) then L(C.rd.." File not found."..C.res)
        else
            local d=JSON.decode(read_file(src))
            if type(d)=="table" then
                for k,v in pairs(d) do cfg[k]=v end
                save_cfg(); L(C.BGR.." Imported."..C.res)
            else L(C.rd.." Invalid JSON."..C.res) end
        end
    end
    nl(); sleep(1.5)
end

-- ═══════════════════════════════════════════════════════════
--  MAIN MENU
-- ═══════════════════════════════════════════════════════════
clr()
local function draw_menu()
    clr(); banner(); sec("MAIN MENU")
    if cfg.configured then
        LF(C.dim.." Pkgs: "..C.cy.."%d"..C.dim.."  URL: "..C.cy.."%s"..C.res,
           #(cfg.packages or {}),
           cfg.game_url~="" and cfg.game_url:sub(1,30) or "none")
    else
        L(C.yw.." Not configured yet -- run Option 1"..C.res)
    end
    LF(C.dim.." Root: %s"..C.res,
       IS_ROOT and C.gr.."Yes"..C.res or C.rd.."No (screenshots off)"..C.res)
    nl()
    L(C.BMW.." 1) First-time configuration"..C.res)
    L(C.BMW.." 2) Start auto-rejoin"..C.res)
    L(C.BMW.." 3) Webhook configuration"..C.res)
    L(C.BMW.." 4) Update URL"..C.res)
    L(C.BMW.." 5) Export / Import config"..C.res)
    L(C.BRD.." 6) Exit"..C.res)
    nl()
end

local function main()
    mkdirs(); load_cfg()
    clr()
    while true do
        draw_menu()
        local c=prompt(" Select [1-6]")
        if     c=="1" then run_wizard();        load_cfg()
        elseif c=="2" then run_auto_rejoin()
        elseif c=="3" then run_webhook_cfg()
        elseif c=="4" then run_update_url()
        elseif c=="5" then run_export_import()
        elseif c=="6" then
            clr(); L(C.BCY.." Goodbye."..C.res); nl(); os.exit(0)
        else
            clr(); banner()
            L(C.rd.." Invalid. Choose 1-6."..C.res); sleep(1)
        end
    end
end

main()
