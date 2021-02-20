-- Zenoh Protocol Dissector For Wireshark
-- Copyright (C) 2021  Carlos Guimarães
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--

---------- Helpers ----------
function protect(tbl)
  return setmetatable({}, {
    __index = tbl,
    __newindex = function(t, key, value)
      error("attempting to change constant " ..
      tostring(key) .. " to " .. tostring(value), 2)
    end
  })
end

function zint_decode(buf)
  local i = 0
  local val = 0

  repeat
    tmp = buf(i, 1):uint()
    val = bit.bor(val, bit.lshift(bit.band(tmp, 0x7f), i * 7))
    i = i + 1
  until (bit.band(tmp, 0x80) == 0x00)

  return val, i
end

function zbytes_decode(buf)
  local i = 0
  local val = 0

  b_val, b_len = zint_decode(buf)
  i = i + b_len + b_val

  return buf(b_len, b_val), i
end

function zstring_decode(buf)
  local i = 0
  local val = 0

  b_val, b_len = zint_decode(buf)
  i = i + b_len + b_val

  return string.fromhex(buf(b_len, b_val)), i
end


---------- CONSTANTS ----------
-- whatami --> Zenoh Message Types
ZENOH_WHATAMI = {
  DECLARE         = 0x0b,
  DATA            = 0x0c,
  QUERY           = 0x0d,
  PULL            = 0x0e,
  UNIT            = 0x0f,
  LINK_STATE_LIST = 0x10
}
ZENOH_WHATAMI = protect(ZENOH_WHATAMI)

-- whatami --> Session Message Types
SESSION_WHATAMI = {
  SCOUT      = 0x01,
  HELLO      = 0x02,
  INIT       = 0x03,
  OPEN       = 0x04,
  CLOSE      = 0x05,
  SYNC       = 0x06,
  ACK_NACK   = 0x07,
  KEEP_ALIVE = 0x08,
  PING_PONG  = 0x09,
  FRAME      = 0x0a
}
SESSION_WHATAMI = protect(SESSION_WHATAMI)

-- whatami --> Decorators Message Types
DECORATORS_WHATAMI = {
  ROUTING_CONTEXT = 0x1d,
  REPLY_CONTEXT   = 0x1e,
  ATTACHMENT      = 0x1f
}
DECORATORS_WHATAMI = protect(DECORATORS_WHATAMI)

-- whatami --> Decorators Message Types
DECLARATION_ID = {
  RESOURCE          = 0x01,
  PUBLISHER         = 0x02,
  SUBSCRIBER        = 0x03,
  QUERYABLE         = 0x04,
  FORGET_RESOURCE   = 0x11,
  FORGET_PUBLISHER  = 0x12,
  FORGET_SUBSCRIBER = 0x13,
  FORGET_QUERYABLE  = 0x14
}
DECLARATION_ID = protect(DECLARATION_ID)


function get_declare_flag_description(flag)
    local f_description = "Unknown"

    if flag == 0x04 then f_description     = "Unused" -- X
    elseif flag == 0x02 then f_description = "Unused" -- X
    elseif flag == 0x01 then f_description = "Unused" -- X
    end

    return f_description
end

function get_declare_resource_flag_description(flag)
    local f_description = "Unknown"

    if flag == 0x04 then f_description     = "CloseLink" -- K
    elseif flag == 0x02 then f_description = "Unused" -- X
    elseif flag == 0x01 then f_description = "Unused" -- X
    end

    return f_description
end

function get_init_flag_description(flag)
    local f_description = "Unknown"

    if flag == 0x04 then f_description     = "Unused"        -- X
    elseif flag == 0x02 then f_description = "SN Resolution" -- S
    elseif flag == 0x01 then f_description = "Ack"           -- A
    end

    return f_description
end

function get_open_flag_description(flag)
    local f_description = "Unknown"

    if flag == 0x04 then f_description = "Unused"      -- X
    elseif flag == 0x02 then f_description = "TimeRes" -- T
    elseif flag == 0x01 then f_description = "Ack"     -- A
    end

    return f_description
end

function get_frame_flag_description(flag)
    local f_description = "Unknown"

    if flag == 0x04 then f_description     = "End"      -- E
    elseif flag == 0x02 then f_description = "Fragment" -- F
    elseif flag == 0x01 then f_description = "Reliable" -- R
    end

    return f_description
end


--- DISSECTOR INFO & FIELDS ---
local proto_zenoh_udp = Proto("zenoh-tcp", "Zenoh Protocol over TCP")
local proto_zenoh_tcp = Proto("zenoh-udp", "Zenoh Protocol over UDP")
local proto_zenoh = Proto("zenoh", "Zenoh Protocol")

-- Zenoh Header
proto_zenoh.fields.header_whatami = ProtoField.uint8("zenoh.whatami", "WhatAmI (Type)", base.HEX)

-- Declare Message Specific
proto_zenoh.fields.declare_flags = ProtoField.uint8 ("zenoh.declare.flags", "Flags", base.HEX)
proto_zenoh.fields.declare_num_of_declaration = ProtoField.uint8 ("zenoh.declare.number", "Number of Declarations", base.u8)
proto_zenoh.fields.declare_declaration_array = ProtoField.bytes ("zenoh.declare.array", "Declaration Array", base.NONE)

-- Init Message Specific
proto_zenoh.fields.init_flags = ProtoField.uint8 ("zenoh.init.flags", "Flags", base.HEX)
proto_zenoh.fields.init_vmaj = ProtoField.uint8 ("zenoh.init.v_maj", "VMaj", base.u8)
proto_zenoh.fields.init_vmin = ProtoField.uint8 ("zenoh.init.v_min", "VMin", base.u8)
proto_zenoh.fields.init_whatami = ProtoField.uint8 ("zenoh.init.whatami", "WhatAmI", base.u8)
proto_zenoh.fields.init_peerid = ProtoField.bytes("zenoh.init.peer_id", "Peer ID", base.NONE)
proto_zenoh.fields.init_snresolution = ProtoField.uint8("zenoh.init.sn_resolution", "SN Resolution", base.u8)
proto_zenoh.fields.init_cookie = ProtoField.bytes("zenoh.init.cookie", "Cookie", base.NONE)

-- Open Message Specific
proto_zenoh.fields.open_flags = ProtoField.uint8 ("zenoh.open.flags", "Flags", base.HEX)
proto_zenoh.fields.open_lease = ProtoField.uint8("zenoh.open.lease", "Lease Period", base.u8)
proto_zenoh.fields.open_initialsn = ProtoField.uint8("zenoh.open.initial_sn", "Initial SN", base.u8)
proto_zenoh.fields.open_cookie = ProtoField.bytes("zenoh.open.cookie", "Cookie", base.NONE)

-- Frame Message Specific
proto_zenoh.fields.frame_flags = ProtoField.uint8 ("zenoh.frame.flags", "Flags", base.HEX)
proto_zenoh.fields.frame_sn = ProtoField.uint8("zenoh.frame.sn", "SN", base.u8)
proto_zenoh.fields.frame_payload = ProtoField.uint8("zenoh.frame.payload", "Payload", base.u8)


------ DISSECTOR HELPERS ------

function parse_whatami(tree, buf)
  local whatami = buf(0, 1):uint()

  if whatami == ZENOH_WHATAMI.DECLARE then
    tree:add(proto_zenoh.fields.header_whatami, whatami, base.u8, "(Declare)")
    return ZENOH_WHATAMI.DECLARE
  elseif whatami == ZENOH_WHATAMI.DATA then
    tree:add(proto_zenoh.fields.header_whatami, whatami, base.u8, "(Data)")
    return ZENOH_WHATAMI.DATA
  elseif whatami == ZENOH_WHATAMI.QUERY then
    tree:add(proto_zenoh.fields.header_whatami, whatami, base.u8, "(Query)")
    return ZENOH_WHATAMI.QUERY
  elseif whatami == ZENOH_WHATAMI.PULL then
    tree:add(proto_zenoh.fields.header_whatami, whatami, base.u8, "(Pull)")
    return ZENOH_WHATAMI.PULL
  elseif whatami == ZENOH_WHATAMI.UNIT then
    tree:add(proto_zenoh.fields.header_whatami, whatami, base.u8, "(Unit)")
    return ZENOH_WHATAMI.UNIT
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.SCOUT then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Scout)")
    return SESSION_WHATAMI.SCOUT
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.HELLO then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Hello)")
    return SESSION_WHATAMI.HELLO
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.INIT then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Init)")
    return SESSION_WHATAMI.INIT
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.OPEN then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Open)")
    return SESSION_WHATAMI.OPEN
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.CLOSE then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Close)")
    return SESSION_WHATAMI.CLOSE
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.SYNC then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Sync)")
    return SESSION_WHATAMI.SYNC
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.ACK_NACK then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(ACK-NACK)")
    return SESSION_WHATAMI.ACK_NACK
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.KEEP_ALIVE then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Keep Alive)")
    return SESSION_WHATAMI.KEEP_ALIVE
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.PING_PONG then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Ping Pong)")
    return SESSION_WHATAMI.PING_PONG
  elseif bit.band(whatami, 0x1F) == SESSION_WHATAMI.FRAME then
    tree:add(proto_zenoh.fields.header_whatami, bit.band(whatami, 0x1F), base.u8, "(Frame)")
    return SESSION_WHATAMI.FRAME
  end

  return NULL
end

function parse_header_flags(tree, buf, whatami)
  local f_bitwise = {0x04, 0x02, 0x01}
  h_flags = bit.rshift(buf(0,1):uint(), 5)

  local f_str = ""
  for i,v in ipairs(f_bitwise) do
    if whatami == ZENOH_WHATAMI.DECLARE then
      flag = get_declare_flag_description(bit.band(h_flags, v))
    elseif whatami == ZENOH_WHATAMI.DATA then
    elseif whatami == ZENOH_WHATAMI.QUERY then
    elseif whatami == ZENOH_WHATAMI.PULL then
    elseif whatami == ZENOH_WHATAMI.UNIT then
    elseif whatami == ZENOH_WHATAMI.LINK_STATE_LIST then
    elseif whatami == SESSION_WHATAMI.SCOUT then
    elseif whatami == SESSION_WHATAMI.HELLO then
    elseif whatami == SESSION_WHATAMI.INIT then
      flag = get_init_flag_description(bit.band(h_flags, v))
    elseif whatami == SESSION_WHATAMI.OPEN then
      flag = get_open_flag_description(bit.band(h_flags, v))
    elseif whatami == SESSION_WHATAMI.CLOSE then
    elseif whatami == SESSION_WHATAMI.SYNC then
    elseif whatami == SESSION_WHATAMI.ACK_NACK then
    elseif whatami == SESSION_WHATAMI.KEEP_ALIVE then
    elseif whatami == SESSION_WHATAMI.PING_PONG then
    elseif whatami == SESSION_WHATAMI.FRAME then
      flag = get_frame_flag_description(bit.band(h_flags, v))
    end

    if bit.band(h_flags, v) == v then
      f_str = f_str .. flag .. ", "
    end
  end

  if whatami == ZENOH_WHATAMI.DECLARE then
    tree:add(proto_zenoh.fields.declare_flags, h_flags):append_text(" (" .. f_str:sub(0, -3) .. ")")
  elseif whatami == ZENOH_WHATAMI.DATA then
  elseif whatami == ZENOH_WHATAMI.QUERY then
  elseif whatami == ZENOH_WHATAMI.PULL then
  elseif whatami == ZENOH_WHATAMI.UNIT then
  elseif whatami == ZENOH_WHATAMI.LINK_STATE_LIST then
  elseif whatami == SESSION_WHATAMI.SCOUT then
  elseif whatami == SESSION_WHATAMI.HELLO then
  elseif whatami == SESSION_WHATAMI.INIT then
    tree:add(proto_zenoh.fields.init_flags, h_flags):append_text(" (" .. f_str:sub(0, -3) .. ")")
  elseif whatami == SESSION_WHATAMI.OPEN then
    tree:add(proto_zenoh.fields.open_flags, h_flags):append_text(" (" .. f_str:sub(0, -3) .. ")")
  elseif whatami == SESSION_WHATAMI.CLOSE then
  elseif whatami == SESSION_WHATAMI.SYNC then
  elseif whatami == SESSION_WHATAMI.ACK_NACK then
  elseif whatami == SESSION_WHATAMI.KEEP_ALIVE then
  elseif whatami == SESSION_WHATAMI.PING_PONG then
  elseif whatami == SESSION_WHATAMI.FRAME then
    tree:add(proto_zenoh.fields.frame_flags, h_flags):append_text(" (" .. f_str:sub(0, -3) .. ")")
  end

  -- TODO: add bitwise flag substree
end


function parse_declare_flags(tree, buf, did)
  local f_bitwise = {0x04, 0x02, 0x01}
  d_flags = bit.rshift(buf(0,1):uint(), 5)

  local f_str = ""
  for i,v in ipairs(f_bitwise) do
    if did == DECLARATION_ID.RESOURCE then
      flag = get_declare_flag_description(bit.band(h_flags, v))
    elseif did == DECLARATION_ID.PUBLISHER then
    elseif did == DECLARATION_ID.SUBSCRIBER then
    elseif did == DECLARATION_ID.QUERYABLE then
    elseif did == DECLARATION_ID.FORGET_RESOURCE then
    elseif did == DECLARATION_ID.FORGET_PUBLISHER then
    elseif did == DECLARATION_ID.FORGET_SUBSCRIBER then
    elseif did == DECLARATION_ID.FORGET_QUERYABLE then
    end

    if bit.band(h_flags, v) == v then
      f_str = f_str .. flag .. ", "
    end
  end

  if did == DECLARATION_ID.RESOURCE then
    tree:add("Flags", d_flags):append_text(" (" .. f_str:sub(0, -3) .. ")") -- FIXME: print in hex
  elseif did == DECLARATION_ID.PUBLISHER then
  elseif did == DECLARATION_ID.SUBSCRIBER then
  elseif did == DECLARATION_ID.QUERYABLE then
  elseif did == DECLARATION_ID.FORGET_RESOURCE then
  elseif did == DECLARATION_ID.FORGET_PUBLISHER then
  elseif did == DECLARATION_ID.FORGET_SUBSCRIBER then
  elseif did == DECLARATION_ID.FORGET_QUERYABLE then
  end

  -- TODO: add bitwise flag substree
end


function parse_header(tree, buf)
  local i = 0

  local whatami = parse_whatami(tree, buf(i, 1))
  parse_header_flags(tree, buf(i, 1), whatami)
  i = i + 1

  return whatami, i
end

function parse_declare_resource(tree, buf)
  local i = 0

  parse_declare_flags(tree, buf(i, 1), DECLARATION_ID.RESOURCE)
  i = i + 1

  local val, len = zint_decode(buf(i, -1))
  tree:add("Resource ID: ", buf(i, len), val)
  i = i + len

  val, len = zint_decode(buf(i, -1))
  tree:add("ResKey Resource ID: ", buf(i, len), val)
  i = i + len

  if bit.band(h_flags, 0x04) == 0x04 then
    val, len = zstring_decode(buf(i, -1))
    tree:add("ResKey Suffix: ", val)
    i = i + len
  end

  return i
end

function parse_declare(tree, buf)
  local i = 0

  local a_size, len = zint_decode(buf(i, -1))
  tree:add(proto_zenoh.fields.declare_num_of_declaration, a_size)
  i = i + len

  while a_size > 0 do
    local did = bit.band(buf(i, 1):uint(), 0x1F)

    if bit.band(did, 0X1F) == DECLARATION_ID.RESOURCE then
      local a_subtree = tree:add("Declaration [" .. a_size .. "] = Resource Declaration")

      len = parse_declare_resource(a_subtree, buf(i, -1))
      i = i + len

    elseif bit.band(did, 0x1F) == DECLARATION_ID.PUBLISHER then
    elseif bit.band(did, 0x1F) == DECLARATION_ID.SUBSCRIBER then
    elseif bit.band(did, 0x1F) == DECLARATION_ID.QUERYABLE then
    elseif bit.band(did, 0x1F) == DECLARATION_ID.FORGET_RESOURCE then
    elseif bit.band(did, 0x1F) == DECLARATION_ID.FORGET_PUBLISHER then
    elseif bit.band(did, 0x1F) == DECLARATION_ID.FORGET_SUBSCRIBER then
    elseif bit.band(did, 0x1F) == DECLARATION_ID.FORGET_QUERYABLE then
    end

    a_size = a_size - 1
  end
 
  return i
end

function parse_init(tree, buf)
  local i = 0

  if bit.band(h_flags, 0x01) == 0x00 then
    tree:add(proto_zenoh.fields.init_vmaj, bit.rshift(buf(i, 1):uint(), 4))
    tree:add(proto_zenoh.fields.init_vmin, bit.band(buf(i, 1):uint(), 0xff))
    i = i + 1
  end

  local val, len = zint_decode(buf(i, -1))
  tree:add(proto_zenoh.fields.init_whatami, val)
  i = i + len

  val, len = zbytes_decode(buf(i, -1))
  tree:add(proto_zenoh.fields.init_peerid, val)
  i = i + len

  if bit.band(h_flags, 0x02) == 0x02 then
    val, len = zbytes_decode(buf(i, -1))
    tree:add(proto_zenoh.fields.init_snresolution, val)
    i = i + len
  end

  if bit.band(h_flags, 0x01) == 0x01 then
    val, len = zbytes_decode(buf(i, -1))
    tree:add(proto_zenoh.fields.init_cookie, val)
    i = i + len
  end

  return i
end

function parse_open(tree, buf)
  local i = 0

  local val, len = zint_decode(buf, i)
  if bit.band(h_flags, 0x02) == 0x02 then
    tree:add(proto_zenoh.fields.open_lease, val):append_text(" seconds")
  else
    tree:add(proto_zenoh.fields.open_lease, val):append_text(" microseconds")
  end
  i = i + len

  val, len = zint_decode(buf(i, -1))
  tree:add(proto_zenoh.fields.open_initialsn, val)
  i = i + len

  if bit.band(h_flags, 0x01) == 0x00 then
    val, len = zbytes_decode(buf(i, -1))
    tree:add(proto_zenoh.fields.open_cookie, val)
    i = i + len
  end

  return i
end

function parse_frame(tree, buf, f_size)
  local i = 0

  local val, len = zint_decode(buf(i, -1))
  tree:add(proto_zenoh.fields.frame_sn, val)
  i = i + len

  repeat
    len = decode_message(tree, buf(i, -1))
    i = i + len
  until i == f_size

  return i
end


---------- DISSECTOR ----------
function dissector(buf, pinfo, root, is_tcp)
  local i = 0

  if buf:len() < 2 and is_tcp == true then return
  elseif buf:len() == 0 and (is_tcp == false or is_frame == true) then return end

  if is_tcp == true then
    f_size = buf(i, 2):le_uint()
    i = i + 2
  else
    f_size = buf():len()
  end

  pinfo.cols.protocol = proto_zenoh.name
  tree = root:add(proto_zenoh, buf())

  decode_message(tree, buf(i, f_size))
end

function decode_message(tree, buf)
  local i = 0

  local h_subtree = tree:add(proto_zenoh, buf(i, 1), "Header")
  local whatami, len = parse_header(h_subtree, buf(i, 1))
  i = i + len

  -- PAYLOAD
  local p_subtree = tree:add(proto_zenoh, buf(i, -1), "Payload")

  if whatami == ZENOH_WHATAMI.DECLARE then
    len = parse_declare(p_subtree, buf(i, -1))
  elseif whatami == ZENOH_WHATAMI.DATA then
  elseif whatami == ZENOH_WHATAMI.QUERY then
  elseif whatami == ZENOH_WHATAMI.PULL then
  elseif whatami == ZENOH_WHATAMI.UNIT then
  elseif whatami == ZENOH_WHATAMI.LINK_STATE_LIST then
  elseif whatami == SESSION_WHATAMI.SCOUT then
  elseif whatami == SESSION_WHATAMI.HELLO then
  elseif whatami == SESSION_WHATAMI.INIT then
    len = parse_init(p_subtree, buf(i, -1))
  elseif whatami == SESSION_WHATAMI.OPEN then
    len = parse_open(p_subtree, buf(i, -1))
  elseif whatami == SESSION_WHATAMI.CLOSE then
  elseif whatami == SESSION_WHATAMI.SYNC then
  elseif whatami == SESSION_WHATAMI.ACK_NACK then
  elseif whatami == SESSION_WHATAMI.KEEP_ALIVE then
  elseif whatami == SESSION_WHATAMI.PING_PONG then
  elseif whatami == SESSION_WHATAMI.FRAME then
    len = parse_frame(p_subtree, buf(i, -i), f_size)
  end
  i = i + len

  return i
end

function proto_zenoh_udp.dissector(buf, pinfo, root)
    dissector(buf, pinfo, root, false)
end

function proto_zenoh_tcp.dissector(buf, pinfo, root)
    dissector(buf, pinfo, root, true)
end

-- register zenoh to handle ports
--  * 7447/tcp : the zenoh protocol via TCP
--  * 7447/udp : the zenoh scouting protocol using UDP multicast
do
    local tcp_port_table = DissectorTable.get("tcp.port")
    tcp_port_table:add(7447, proto_zenoh_tcp)

    local udp_port_table = DissectorTable.get("udp.port")
    udp_port_table:add(7447, proto_zenoh_udp)
end

