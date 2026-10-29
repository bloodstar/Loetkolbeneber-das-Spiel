class_name EosFragmentPeer
extends MultiplayerPeerExtension

# Hülle um den EOS-P2P-Peer (EOSGMultiplayerPeer).
# EOS-Pakete dürfen höchstens ~1170 Byte groß sein, Snapshots und Lobby-Syncs
# sind oft größer. Diese Klasse zerlegt große Pakete in Stücke und setzt sie beim
# Empfänger wieder zusammen. Für Godots RPC-System sieht sie aus wie ein
# normaler MultiplayerPeer ohne Größenlimit.

# Platz für den EOSG-Header (6 Byte) und Reserve unter dem EOS-Limit.
const MAX_WIRE_BYTES: int = 1100
const HEADER_WHOLE: int = 0
const HEADER_FRAGMENT: int = 1
const FRAGMENT_HEADER_SIZE: int = 5
const CHUNK_BYTES: int = MAX_WIRE_BYTES - FRAGMENT_HEADER_SIZE
const MAX_FRAGMENTS: int = 255
# Unvollständige Nachrichten (verlorene unzuverlässige Stücke) werden verworfen.
const FRAGMENT_TIMEOUT_MS: int = 2000

var _inner: MultiplayerPeer
var _target_peer: int = 0
var _transfer_mode: int = TRANSFER_MODE_RELIABLE
var _transfer_channel: int = 0
var _next_message_id: int = 0
# Fertig empfangene Pakete: {data, peer, channel, mode}
var _incoming: Array[Dictionary] = []
# "peer:id" -> {count, parts, received, channel, mode, started}
var _partial: Dictionary = {}
var _current: Dictionary = {}

func _init(inner: MultiplayerPeer) -> void:
	_inner = inner
	_inner.peer_connected.connect(func(id: int): peer_connected.emit(id))
	_inner.peer_disconnected.connect(_on_inner_peer_disconnected)

func get_inner() -> MultiplayerPeer:
	return _inner

# --- Senden ---

func _put_packet_script(buffer: PackedByteArray) -> Error:
	_inner.set_target_peer(_target_peer)
	# EOS kennt kein "unzuverlässig, aber geordnet"; dann lieber zuverlässig.
	var mode := _transfer_mode
	if mode == TRANSFER_MODE_UNRELIABLE_ORDERED:
		mode = TRANSFER_MODE_RELIABLE
	_inner.transfer_mode = mode
	_inner.transfer_channel = _transfer_channel

	if buffer.size() + 1 <= MAX_WIRE_BYTES:
		var whole := PackedByteArray([HEADER_WHOLE])
		whole.append_array(buffer)
		return _inner.put_packet(whole)

	var count := ceili(float(buffer.size()) / CHUNK_BYTES)
	if count > MAX_FRAGMENTS:
		push_error("EosFragmentPeer: Paket zu groß (%d Byte)." % buffer.size())
		return ERR_OUT_OF_MEMORY
	var message_id := _next_message_id
	_next_message_id = (_next_message_id + 1) & 0xFFFF
	for index in count:
		var chunk := PackedByteArray([HEADER_FRAGMENT, message_id & 0xFF, (message_id >> 8) & 0xFF, index, count])
		chunk.append_array(buffer.slice(index * CHUNK_BYTES, mini((index + 1) * CHUNK_BYTES, buffer.size())))
		var err := _inner.put_packet(chunk)
		if err != OK:
			return err
	return OK

# --- Empfangen ---

func _poll() -> void:
	_inner.poll()
	while _inner.get_available_packet_count() > 0:
		var from := _inner.get_packet_peer()
		var channel := _inner.get_packet_channel()
		var mode := _inner.get_packet_mode()
		var data := _inner.get_packet()
		_handle_incoming(data, from, channel, mode)
	_drop_stale_fragments()

func _handle_incoming(data: PackedByteArray, from: int, channel: int, mode: int) -> void:
	if data.is_empty():
		return
	if data[0] == HEADER_WHOLE:
		_incoming.append({data = data.slice(1), peer = from, channel = channel, mode = mode})
		return
	if data[0] != HEADER_FRAGMENT or data.size() <= FRAGMENT_HEADER_SIZE:
		return
	var message_id := int(data[1]) | (int(data[2]) << 8)
	var index := int(data[3])
	var count := int(data[4])
	if count == 0 or index >= count:
		return
	var key := "%d:%d" % [from, message_id]
	var entry: Dictionary = _partial.get(key, {})
	if entry.is_empty() or int(entry.count) != count:
		var parts: Array = []
		parts.resize(count)
		entry = {count = count, parts = parts, received = 0, channel = channel, mode = mode, started = Time.get_ticks_msec()}
		_partial[key] = entry
	var parts_ref: Array = entry.parts
	if parts_ref[index] != null:
		return
	parts_ref[index] = data.slice(FRAGMENT_HEADER_SIZE)
	entry.received = int(entry.received) + 1
	if int(entry.received) < count:
		return
	_partial.erase(key)
	var full := PackedByteArray()
	for part in parts_ref:
		full.append_array(part)
	_incoming.append({data = full, peer = from, channel = int(entry.channel), mode = int(entry.mode)})

func _drop_stale_fragments() -> void:
	if _partial.is_empty():
		return
	var now := Time.get_ticks_msec()
	for key in _partial.keys():
		if now - int(_partial[key].started) > FRAGMENT_TIMEOUT_MS:
			_partial.erase(key)

func _on_inner_peer_disconnected(id: int) -> void:
	var prefix := "%d:" % id
	for key in _partial.keys():
		if String(key).begins_with(prefix):
			_partial.erase(key)
	peer_disconnected.emit(id)

func _get_available_packet_count() -> int:
	return _incoming.size()

func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		_current = {}
		return PackedByteArray()
	_current = _incoming.pop_front()
	return _current.data

func _get_packet_peer() -> int:
	if _incoming.is_empty():
		return 0
	return int(_incoming[0].peer)

func _get_packet_channel() -> int:
	if _incoming.is_empty():
		return 0
	return int(_incoming[0].channel)

func _get_packet_mode() -> TransferMode:
	if _incoming.is_empty():
		return TRANSFER_MODE_RELIABLE
	return int(_incoming[0].mode) as TransferMode

func _get_max_packet_size() -> int:
	return CHUNK_BYTES * MAX_FRAGMENTS

# --- Durchreichen an den EOS-Peer ---

func _set_target_peer(peer: int) -> void:
	_target_peer = peer

func _set_transfer_mode(mode: TransferMode) -> void:
	_transfer_mode = mode

func _get_transfer_mode() -> TransferMode:
	return _transfer_mode as TransferMode

func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel

func _get_transfer_channel() -> int:
	return _transfer_channel

func _get_unique_id() -> int:
	return _inner.get_unique_id()

func _get_connection_status() -> ConnectionStatus:
	return _inner.get_connection_status()

func _is_server() -> bool:
	return _inner.get_unique_id() == 1

func _is_server_relay_supported() -> bool:
	return _inner.is_server_relay_supported()

func _set_refuse_new_connections(enable: bool) -> void:
	_inner.refuse_new_connections = enable

func _is_refusing_new_connections() -> bool:
	return _inner.refuse_new_connections

func _disconnect_peer(peer: int, force: bool) -> void:
	_inner.disconnect_peer(peer, force)

func _close() -> void:
	_incoming.clear()
	_partial.clear()
	_inner.close()
