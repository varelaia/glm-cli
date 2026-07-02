# glm-cli

> Ejecuta **Claude Code** sobre **Z.ai GLM-5.2** — un modelo de código con contexto de 1M — sin tocar tu `claude` por defecto.

`glm` y `glmf` son dos *wrappers* livianos que lanzan el binario real de Claude Code con variables de entorno acotadas a esa única invocación, apuntándolo al endpoint *Anthropic-compatible* de Z.ai. Tu comando `claude` (API Anthropic / plan Max) **nunca se modifica**: no se toca el `settings.json` global, así que ambos mundos coexisten en la misma shell.

| Comando | Modelo | Cuándo |
|---------|-------|--------|
| `glm`   | `glm-5.2[1m]` (ctx 1M, *thinking* ON) | Trabajo duro — debug, multi-paso, contexto largo |
| `glmf`  | `glm-5-turbo` (*thinking* OFF) | Tareas rápidas — edits, *lookups*, un solo prompt |
| `claude`| *(sin cambios)* | Tu *default* — Anthropic / Max |

## 💡 El diferenciador: API key + tarifa plana

Z.ai te da una **API key** (estándar *Anthropic-compatible*) con **tarifa plana mensual** (Lite $18 / Pro $72 / Max $160) — portable a *cualquier* cliente, incluido este Claude Code.

**Claude y Codex no ofrecen eso.** Ambos tienen planes de tarifa plana (Claude Max, ChatGPT/Codex), pero **atados a su propio CLI o web**. Si quieres su modelo vía **API key** en otro cliente, es estrictamente **pago por token**: la API de Anthropic y de OpenAI no tienen plan *flat-rate*.

| Proveedor | Tarifa plana en su propio CLI | **API key** + tarifa plana |
|---|:---:|:---:|
| **Z.ai (GLM)** | ✓ | ✓ — portátil a cualquier cliente |
| **Claude (Anthropic)** | ✓ (Pro / Max) | ✗ — la API es solo pago por token |
| **Codex (OpenAI)** | ✓ (ChatGPT) | ✗ — la API es solo pago por token |

→ Por eso existe `glm-cli`: correr **Claude Code** (skills, agentes, MCP — todo el UX) sobre **GLM-5.2 a tarifa plana**, usando una API key de Z.ai.

> *Nota honesta: Z.ai tiene límites de uso por plan (Pro ~400 prompts/5 h, Max ~1600/5 h) — tarifa plana, **no** uso ilimitado.*

## ✅ Plataformas soportadas

**No funciona en todos los sistemas.** Depende de dos cosas: que tu SO corra `bash` + `curl`, y que el **instalador nativo de Claude** (que este script invoca) lo soporte. Matriz real, verificada contra el código de ambos instaladores:

| Sistema | ¿Funciona? | Notas |
|---------|:----------:|-------|
| **Linux** (cualquier distro con bash) | ✅ | Nativo |
| **macOS** | ✅ | bash 3.2 y zsh soportados; detecta tu *shell* y escribe el `rc` correcto |
| **Windows vía WSL** (Ubuntu, etc.) | ✅ | Dentro de WSL es Linux → funciona igual |
| **Windows nativo** (PowerShell / cmd) | ❌ | Este script es bash. Necesitas WSL, o un port a `.ps1`/`.cmd` (no incluido) |
| **Git Bash / MSYS2 / Cygwin** (en Windows) | ❌ | El instalador nativo de Claude **los rechaza**: `Windows is not supported by this script` |

> **¿Usas Windows nativo?** La forma soportada de usar glm-cli es **WSL**. Si lo necesitas en PowerShell nativo (*wrappers* `.cmd`/`.ps1`), abre un issue — es un port separado que no está incluido aquí.

## Requisitos

- **bash** + **curl** (vienen en toda distro Linux y en macOS).
- Una **API key de Z.ai** (ver más abajo).
- Conexión a internet (la 1ª vez se descargan Claude Code y los *wrappers*).

## ⚡ Instalación rápida

**Linux / macOS / WSL** — un solo comando:

```bash
curl -fsSL https://raw.githubusercontent.com/varelaia/glm-cli/main/install.sh | bash
```

> **Ojo — `curl | bash` ejecuta un script remoto que no leíste** (el mismo *trade-off* que asume el instalador de Antigravity). Si prefieres auditarlo primero, clona, lee `install.sh` y córrelo:
>
> ```bash
> git clone https://github.com/varelaia/glm-cli
> cd glm-cli && bash install.sh
> ```

El instalador es **idempotente** y hace 5 cosas:

1. Instala Claude Code vía el instalador nativo oficial (lo saltea si ya está).
2. Asegura que `~/.local/bin` esté en tu `PATH` — escribe tu `.bashrc` / `.zshrc` / `.profile` según tu *shell*, **sin duplicar** líneas (detecta las que ya existen en forma `$HOME` o expandida).
3. Instala `glm` y `glmf` en `~/.local/bin` (ejecutables) — los lee de `./bin` si clonaste, o los descarga del repo si usaste `curl|bash`.
4. Pide tu API key de Z.ai y la guarda en `~/.zai_api_key` (`chmod 600`). Acepta la key de un *prompt* interactivo, o no interactivamente desde la variable `ZAI_API_KEY`.
5. Verifica *end-to-end* contra `https://api.z.ai/api/anthropic` (una llamada real a `glm-5.2` esperando HTTP 200).

Después, abre una *shell* nueva y corre `glm`. En el primer arranque Claude Code pregunta *"Use this API key?"* → **Yes** (una vez). Confirma el modelo con `/model`.

### Obtener una API key de Z.ai

1. Crea cuenta en **https://z.ai**.
2. Ve a **https://z.ai/manage-apikey** → *API Keys* → *Create*.
3. Suscríbete a un plan de *coding* (p. ej. **GLM Coding Pro**, mensual) en **https://z.ai/payment**.
4. Copia la key completa. Tiene la forma `<32 chars hex>.<sufijo>` — si no, se truncó y la autenticación fallará.

## Cómo se preserva tu `claude` por defecto

Cada *wrapper* es un script plano:

```bash
ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
ANTHROPIC_AUTH_TOKEN="$ZAI_KEY" \
ANTHROPIC_DEFAULT_OPUS_MODEL="glm-5.2[1m]" \
...
exec claude "$@"
```

Las variables `ANTHROPIC_*` se setean **inline antes de `claude`**, así que aplican solo a ese proceso — nunca filtran a tu *shell* ni a tu config. Nada escribe en `~/.claude/settings.json`. Contrasta con `npx @z_ai/coding-helper`, que edita el *settings* global y haría de Z.ai tu *default*; este proyecto lo evita deliberadamente.

## Modelos

Verificados disponibles en el endpoint *Anthropic-compatible* de Z.ai:

| Model id | Notas |
|----------|-------|
| `glm-5.2[1m]` | Contexto de 1M tokens; razona por defecto (`glm` usa este) |
| `glm-5-turbo` | Variante rápida de GLM-5 (~1.3 s/turno); `glmf` usa este |
| `glm-4.7` | Nivel medio |
| `glm-4.6` | Nivel medio |
| `glm-4.5-air` | Ligero; usado como *tier* haiku por `glm` |

## Solución de problemas

- **`Authentication Failed` (type 1000)** — Z.ai requiere `Authorization: Bearer <key>` (la variable `ANTHROPIC_AUTH_TOKEN`), **no** `x-api-key`. Los *wrappers* ya lo hacen; si lo ves, la key falta o está truncada. Revísala en https://z.ai/manage-apikey.
- **`API error · Retrying in Ns`** a mitad de sesión — es el **límite de peticiones por minuto** del plan (HTTP 429), no un bug de configuración. Claude Code hace *backoff* y reintenta solo. Paceá los turnos rápidos, usa `glmf` para lo liviano, o sube de plan.
- **`glm: command not found`** tras instalar — `~/.local/bin` no está en el `PATH` de la *shell* actual. Corre `source ~/.bashrc` (o abre una terminal nueva). En macOS con zsh, asegúrate de que esté en `~/.zshrc`.
- **Aviso de formato de key** — las keys de Z.ai son `32 chars hex` + `.` + `sufijo`. Si el instalador avisa que se ve mal, probablemente copiaste solo una parte.
- **`Windows is not supported by this script`** — estás en Git Bash / MSYS / Cygwin; el instalador nativo de Claude los rechaza. Usá **WSL** (o Linux/macOS).
- **Claude Code no instala** — el instalador nativo puede reportar regiones no soportadas; revisa https://www.anthropic.com/supported-countries.

## Rollback

```bash
rm -f ~/.zai_api_key ~/.local/bin/glm ~/.local/bin/glmf
```

Eso es todo — no hay estado global que deshacer.

## Tests

La lógica de PATH y la instalación están testeadas:

- `tests/test_path_idempotency.sh` — *unit*: 6 casos (no duplica la línea PATH existente en forma `$HOME` o expandida; persiste aunque el PATH esté cargado solo en la sesión).
- `tests/e2e_one_liner.sh` — *E2E*: corre el `install.sh` aislado en un `HOME` temporal, verificando que los *wrappers* se instalan y tu `.bashrc` real no se toca.

Correrlos: `bash tests/test_path_idempotency.sh && bash tests/e2e_one_liner.sh`

## Por qué

Dos razones para llegar a esto:

1. **Diversidad de modelos / costo.** GLM-5.2 es un modelo de código fuerte con ventana de 1M a tarifa mensual plana, complementando una suscripción Claude Max.
2. **Soberanía sobre el ruteo.** Decidís por invocación qué *backend* corre, desde el mismo UX de Claude Code (*skills*, *slash commands*, *agents*, *MCP* se heredan sin cambios — son plomería del *harness*, modelo-agnóstica).

## Licencia

MIT — ver [LICENSE](LICENSE).
