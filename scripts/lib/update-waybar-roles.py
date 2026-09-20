#!/usr/bin/env python3
"""Update owned Waybar actions while preserving JSONC comments and other settings."""

import json
from pathlib import Path
import sys

# Use the same JSONC grammar as the installed Waybar launcher without writing
# bytecode into the source dotfiles tree during setup or dry-run.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'dotfiles/.config/waybar/scripts'))
from hss_jsonc import TOKENS, json_text

DECODER = json.JSONDecoder()


def skip_space(text, pos):
    while pos < len(text) and text[pos].isspace():
        pos += 1
    return pos


def object_members(text):
    clean = json_text(text)
    value = json.loads(clean)
    if not isinstance(value, dict):
        raise ValueError('Waybar module must be an object')
    pos = skip_space(clean, 0) + 1
    members = {}
    previous_comma = None
    while clean[skip_space(clean, pos)] != '}':
        start = skip_space(clean, pos)
        key, end = DECODER.raw_decode(clean, start)
        value_start = skip_space(clean, skip_space(clean, end) + 1)
        _, value_end = DECODER.raw_decode(clean, value_start)
        delimiter = skip_space(clean, value_end)
        comma = delimiter if clean[delimiter] == ',' or text[delimiter] == ',' else None
        # A trailing comma was blanked; find it in the original gap instead.
        if comma is None:
            gap = TOKENS.sub(lambda m: ' ' * len(m.group()) if not m.group().startswith('"') else m.group(), text[value_end:delimiter])
            offset = gap.find(',')
            if offset >= 0:
                comma = value_end + offset
        members[key] = (start, value_start, value_end, previous_comma, comma)
        previous_comma = comma
        pos = (comma + 1) if comma is not None else value_end
    return members, skip_space(clean, pos)


def apply_edits(text, edits):
    merged = []
    for start, end, replacement in sorted(edits):
        if merged and start < merged[-1][1]:
            prior = merged[-1]
            if replacement or prior[2]:
                raise ValueError('overlapping Waybar edits')
            merged[-1] = (prior[0], max(end, prior[1]), '')
        else:
            merged.append((start, end, replacement))
    for start, end, replacement in reversed(merged):
        text = text[:start] + replacement + text[end:]
    return text


def update_object(text, updates, removed=()):
    members, closing = object_members(text)
    edits = []
    additions = {}
    for key, value in updates.items():
        encoded = json.dumps(value, ensure_ascii=False)
        if key in members:
            _, start, end, _, _ = members[key]
            edits.append((start, end, encoded))
        else:
            additions[key] = value
    for key in removed:
        if key in members:
            start, _, end, before, after = members[key]
            edits.append((start if after is not None else (before if before is not None else start),
                          after + 1 if after is not None else end, ''))
    text = apply_edits(text, edits)
    if additions:
        members, closing = object_members(text)
        trailing = bool(members) and next(reversed(members.values()))[4] is not None
        prefix = ',' if members and not trailing else ''
        fields = ',\n'.join('  ' + json.dumps(key) + ': ' + json.dumps(value, ensure_ascii=False)
                            for key, value in additions.items())
        text = text[:closing] + prefix + '\n' + fields + '\n' + text[closing:]
    json.loads(json_text(text))
    return text


def update_bar(text):
    actions = {
        'clock': {'on-click': '$HOME/.config/hypr/scripts/float_calendar.sh'},
        'pulseaudio': {'on-click': '$HOME/.config/waybar/scripts/audio_control.sh',
                      'on-click-right': '$HOME/.config/waybar/scripts/alsamixer.sh'},
        'bluetooth': {'on-click': '$HOME/.config/waybar/scripts/bluetooth_manager.sh'},
        'network': {'on-click': '$HOME/.config/waybar/scripts/nmtui-connect.sh',
                    'on-click-right': '$HOME/.config/waybar/scripts/nmtui.sh'},
        'custom/notification': {
            'exec': '$HOME/.config/waybar/scripts/notification_status.sh',
            'on-click': '$HOME/.config/hypr/scripts/notification_control.sh toggle',
            'on-click-right': '$HOME/.config/hypr/scripts/notification_control.sh dnd'},
    }
    members, _ = object_members(text)
    edits = []
    for module, updates in actions.items():
        if module not in members:
            continue
        _, start, end, _, _ = members[module]
        removed = ('interval', 'exec-if') if module == 'custom/notification' else ()
        edits.append((start, end, update_object(text[start:end], updates, removed)))
    return apply_edits(text, edits)


def update_document(text):
    clean = json_text(text)
    parsed = json.loads(clean)
    if isinstance(parsed, dict):
        result = update_bar(text)
    elif isinstance(parsed, list):
        edits = []
        pos = skip_space(clean, 0) + 1
        for _ in parsed:
            pos = skip_space(clean, pos)
            _, end = DECODER.raw_decode(clean, pos)
            edits.append((pos, end, update_bar(text[pos:end])))
            pos = skip_space(clean, end)
            if clean[pos] == ',':
                pos += 1
        result = apply_edits(text, edits)
    else:
        raise ValueError('Waybar configuration must be an object or array of objects')
    json.loads(json_text(result))
    return result


if __name__ == '__main__':
    try:
        sys.stdout.write(update_document(Path(sys.argv[1]).read_text()))
    except (ValueError, OSError, IndexError) as error:
        print(f'Cannot update Waybar configuration: {error}', file=sys.stderr)
        sys.exit(1)
