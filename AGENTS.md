# AGENTS.md

## Project Context

This project is the Finspan board game iPad app.

Use Swift and SwiftUI. Treat the app as an interactive multiplayer board game, not a single-player toy or UI-only prototype.

## Core Architecture Rules

- Keep the rules engine, room system, and SwiftUI interface separated.
- The future cloud server is the source of truth for a game room.
- The Host is only a player with management permissions, not the authoritative game server.
- The first version must use `LocalAuthoritativeRoomService` to simulate server behavior locally.
- UI must never directly mutate `GameState`.
- UI may only express player intent by sending a `PlayerCommand`.
- `GameEngine` receives a command, validates whether it is legal, and emits `GameEvent` values.
- `GameState` may only be updated by applying `GameEvent` values.
- All randomness must be controlled by the room service, including values such as `randomSeed`, `shuffledDeck`, and event sequence.
- Do not hard-code Finspan rules inside SwiftUI views.

## Development Workflow

- Before every large change, explain the implementation plan first.
- After every change, summarize which files changed, why they changed, and the recommended next step.
- Prefer testable pure Swift logic before building UI.
- Keep domain rules deterministic and easy to test.
- Keep SwiftUI views focused on presentation and user intent collection.
- Design local services so they can later be replaced by Pass & Play, local nearby networking, Game Center, online rooms, Sharks & Reefs expansion support, and Nautoma solo mode.
