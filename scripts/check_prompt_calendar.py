#!/usr/bin/env python3
"""Mirror of Shared/PromptCalendar.swift for machines without Xcode."""

PROMPTS = 40
WINDOW_MINUTES = 13 * 60 + 30


def stable_hash(text: str) -> int:
    value = 14695981039346656037
    for byte in text.encode():
        value ^= byte
        value = (value * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return value


def main() -> None:
    prompt_hash = stable_hash("prompt|K7MQ2P|2026-10-15")
    time_hash = stable_hash("time|K7MQ2P|2026-10-15")
    assert prompt_hash == 17488028170258340024
    assert time_hash == 6120781827179909315
    assert 0 <= time_hash % WINDOW_MINUTES < WINDOW_MINUTES
    assert stable_hash("time|H4NP8R|2026-10-15") % WINDOW_MINUTES != time_hash % WINDOW_MINUTES
    assert prompt_hash % PROMPTS == 24
    print("prompt calendar checks passed")


if __name__ == "__main__":
    main()
