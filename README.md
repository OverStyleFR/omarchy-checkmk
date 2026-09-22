# tomv.checkmk

A Quickshell bar widget for [Omarchy](https://omarchy.org/) that supervises a remote **CheckMK** instance via its REST API.

- **Bar**: global alert counter + icon coloured by the worst state.
- **Panel**: grouped list of hosts/services in anomaly with actions Acknowledge, Recheck (see note) and Open in CheckMK.

## Installation

### 1. Copy or clone the plugin

```bash
# Marketplace / manual install
mkdir -p ~/.config/omarchy/plugins
cp -r tomv.checkmk ~/.config/omarchy/plugins/
```

### 2. Configure credentials

Create `~/.config/tomv.checkmk/.env` with your CheckMK automation user credentials:

```bash
CHECKMK_USERNAME=automation
CHECKMK_SECRET=your-automation-secret
```

Set strict permissions:

```bash
chmod 600 ~/.config/tomv.checkmk/.env
```

### 3. Configure the widget

Edit `~/.config/omarchy/shell.json` and add `tomv.checkmk` to a bar section, e.g.:

```json
{
  "bar": {
    "layout": {
      "right": ["tomv.checkmk"]
    }
  }
}
```

Then set your CheckMK site URL:

```bash
omarchy bar set tomv.checkmk baseUrl https://checkmk.example.com/monitoring
```

Replace `monitoring` with your actual CheckMK site name.

### 4. Validate and reload

```bash
omarchy plugin validate ~/.config/omarchy/plugins/tomv.checkmk
omarchy restart shell
```

## Settings

| Key | Type | Default | Description |
|---|---|---|---|
| `baseUrl` | string | `https://checkmk.example.com/monitoring` | CheckMK base URL (site path). |
| `apiVersion` | string | `1.0` | REST API version segment. |
| `refreshIntervalSec` | integer | `30` | Polling interval. |
| `showAcknowledged` | boolean | `false` | Include acknowledged problems. |
| `maxItemsInPanel` | integer | `50` | Max problems shown in the panel. |
| `useHostAlerts` | boolean | `true` | Include host DOWN/UNREACHABLE. |
| `useServiceAlerts` | boolean | `true` | Include service CRIT/WARN/UNKNOWN. |
| `acknowledgeComment` | string | `Ack from Omarchy bar` | Comment used for acknowledgements. |

Set with:

```bash
omarchy bar set tomv.checkmk <key> <value>
# For booleans/numbers:
omarchy bar set tomv.checkmk showAcknowledged true --json
```

## Dependencies

- `curl`
- `jq`
- CheckMK automation user with permissions:
  - `Monitoring user` role for reading host/service status
  - Acknowledgement action also requires the `Acknowledge and schedule downtime` permission (admin/monitoring power user)

## CheckMK automation user setup

1. In CheckMK, go to **Setup → Users → Add user**.
2. Enable **Automation secret for machine accounts** and copy the secret.
3. Assign the **Administrator** or a custom role with monitoring read + acknowledge permissions.
4. Save and **Activate on selected sites**.

## Usage

- **Left click**: toggle panel.
- **Right click**: force refresh.
- **Esc**: close panel.
- **r**: refresh.
- **a**: acknowledge selected problem.
- **Enter / click row**: open the host/service in CheckMK.

### Acknowledge

Select a problem and press `a` or click the checkmark icon. The comment is taken from the `acknowledgeComment` setting.

### Recheck / reschedule

**Important**: the public CheckMK REST API does **not** expose a reschedule/recheck endpoint. The Recheck button will inform you that this action must be performed from the CheckMK web UI. Use **Open in CheckMK** and click the Reschedule action there.

## License

MIT — see [LICENSE](LICENSE).
