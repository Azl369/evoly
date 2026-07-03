---
name: openmontage
description: OpenMontage video-production skill pack, fixed into this project. Use when the user mentions OpenMontage or asks for video production, montage, trailers, explainers, short-form clips, b-roll, subtitles, dubbing, screen demos, animation, Remotion, HyperFrames, FFmpeg, AI video prompts, image/audio generation guidance, or video review workflows.
---

# OpenMontage

This project-local skill wraps the OpenMontage markdown skill tree copied into
`references/`. It provides production, creative, and review guidance only; the
OpenMontage Python tools, Remotion project, assets, provider integrations, and
Layer 3 `.agents/skills` runtime collection are not vendored here.

## First Step

When this skill is selected, read:

1. `references/skills/INDEX.md` for the skill map.
2. `references/AGENT_GUIDE.md` when planning or executing a meaningful video
   workflow.
3. Only the specific skill files needed for the user request.

Do not apply OpenMontage rules globally to ordinary Evoly Flutter development.
Use these references only for media/video/creative-production tasks.

## Routing

- Video editing, pacing, cuts, montage: read
  `references/skills/creative/video-editing.md`,
  `references/skills/creative/video-stitching.md`, and
  `references/skills/core/ffmpeg.md`.
- B-roll, stock/source media, cinematic language: read
  `references/skills/creative/broll-planning.md`,
  `references/skills/creative/stock-sourcing-usage.md`, and
  `references/skills/creative/cinematic.md`.
- Explainers, short-form, long-form, screen demos, podcasts, localization,
  avatar videos, or cinematic pieces: read the matching directory under
  `references/skills/pipelines/`.
- AI video prompting: read
  `references/skills/creative/video-gen-prompting.md`, then the relevant
  provider file under `references/skills/creative/prompting/`.
- Image, diagram, typography, data visualization, sound, music, subtitles,
  dubbing, enhancement, or restoration: read the matching file under
  `references/skills/creative/` or `references/skills/core/`.
- Remotion or HyperFrames composition: read
  `references/skills/core/remotion.md` or
  `references/skills/core/hyperframes.md`.
- Review/checkpoints/meta workflow: read
  `references/skills/meta/reviewer.md` and
  `references/skills/meta/checkpoint-protocol.md`.

## Local Constraints

- Verify any external tool, model, API key, or runtime before assuming it is
  available on this machine.
- Keep generated media outputs outside app source folders unless the user asks
  to add them to the app.
- Prefer D-drive working directories for large media artifacts, caches, and
  downloads.
- If the request touches Evoly Flutter code, also use the Evoly development
  environment skill.

