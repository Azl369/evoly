# OpenMontage Skill Pack Provenance

- Source: https://github.com/calesthio/OpenMontage
- Commit copied: `0c202b507a848bfceb131207cee1941318ed8b76`
- Copied into this project: 2026-07-03
- Local entry skill: `skills/openmontage/SKILL.md`

## Copied Paths

- `skills/` -> `skills/openmontage/references/skills/`
- `AGENT_GUIDE.md` -> `skills/openmontage/references/AGENT_GUIDE.md`
- `PROJECT_CONTEXT.md` -> `skills/openmontage/references/PROJECT_CONTEXT.md`
- `LICENSE` -> `skills/openmontage/LICENSE.openmontage`

## Intentionally Omitted

- OpenMontage Python tool implementations under `tools/`
- Remotion project under `remotion-composer/`
- Media assets under `assets/`
- Pipeline manifests, schemas, tests, and runtime scripts
- Layer 3 `.agents/skills/` collection

Those omitted parts are sizeable runtime/tooling dependencies and should only
be imported deliberately if this project starts doing actual video production.

## License Note

OpenMontage is distributed under the GNU Affero General Public License v3.0.
The copied OpenMontage reference files are preserved with the upstream license
text in `LICENSE.openmontage`.

