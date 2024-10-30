package networkmanager

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/warewulf/warewulf/internal/app/wwctl/overlay/show"
	"github.com/warewulf/warewulf/internal/pkg/testenv"
	"github.com/warewulf/warewulf/internal/pkg/wwlog"
)

func Test_networkmanagerOverlay(t *testing.T) {
	env := testenv.New(t)
	defer env.RemoveAll(t)
	env.ImportFile(t, "etc/warewulf/nodes.conf", "nodes.conf")
	env.ImportFile(t, "var/lib/warewulf/overlays/NetworkManager/rootfs/etc/NetworkManager/conf.d/ww4-unmanaged.ww", "../rootfs/etc/NetworkManager/conf.d/ww4-unmanaged.ww")
	env.ImportFile(t, "var/lib/warewulf/overlays/NetworkManager/rootfs/etc/NetworkManager/system-connections/ww4-managed.ww", "../rootfs/etc/NetworkManager/system-connections/ww4-managed.ww")

	tests := []struct {
		name string
		args []string
		log  string
	}{
		{
			name: "NetworkManager:ww4-unmanaged.ww",
			args: []string{"--render", "node1", "NetworkManager", "etc/NetworkManager/conf.d/ww4-unmanaged.ww"},
			log:  networkmanager_unmanaged,
		},
		{
			name: "NetworkManager:ww4-managed.ww",
			args: []string{"--render", "node1", "NetworkManager", "etc/NetworkManager/system-connections/ww4-managed.ww"},
			log:  networkmanager_managed,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cmd := show.GetCommand()
			cmd.SetArgs(tt.args)
			stdout := bytes.NewBufferString("")
			stderr := bytes.NewBufferString("")
			logbuf := bytes.NewBufferString("")
			cmd.SetOut(stdout)
			cmd.SetErr(stderr)
			wwlog.SetLogWriter(logbuf)
			err := cmd.Execute()
			assert.NoError(t, err)
			assert.Empty(t, stdout.String())
			assert.Empty(t, stderr.String())
			assert.Equal(t, tt.log, logbuf.String())
		})
	}
}

func Test_unmanaged_networkmanagerOverlay_with_empty_mac(t *testing.T) {
	env := testenv.New(t)
	defer env.RemoveAll(t)
	env.ImportFile(t, "etc/warewulf/nodes.conf", "nodes_empty_mac.conf")
	env.ImportFile(t, "var/lib/warewulf/overlays/NetworkManager/rootfs/etc/NetworkManager/conf.d/ww4-unmanaged.ww", "../rootfs/etc/NetworkManager/conf.d/ww4-unmanaged.ww")

	tests := []struct {
		name string
		args []string
		log  string
	}{
		{
			name: "NetworkManager:ww4-unmanaged.ww",
			args: []string{"--render", "node1", "NetworkManager", "etc/NetworkManager/conf.d/ww4-unmanaged.ww"},
			log:  networkmanager_unmanaged_with_empty_mac,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cmd := show.GetCommand()
			cmd.SetArgs(tt.args)
			stdout := bytes.NewBufferString("")
			stderr := bytes.NewBufferString("")
			logbuf := bytes.NewBufferString("")
			cmd.SetOut(stdout)
			cmd.SetErr(stderr)
			wwlog.SetLogWriter(logbuf)
			err := cmd.Execute()
			assert.NoError(t, err)
			assert.Empty(t, stdout.String())
			assert.Empty(t, stderr.String())
			assert.Equal(t, tt.log, logbuf.String())
		})
	}
}

const networkmanager_unmanaged_with_empty_mac string = `backupFile: true
writeFile: true
Filename: warewulf-unmanaged.conf
# This file is autogenerated by warewulf
[main]
plugins=keyfile

[keyfile]
unmanaged-devices=except:interface-name:wwnet0,except:mac:9a:77:29:73:14:f1,except:interface-name:wwnet1,
`

const networkmanager_unmanaged string = `backupFile: true
writeFile: true
Filename: warewulf-unmanaged.conf
# This file is autogenerated by warewulf
[main]
plugins=keyfile

[keyfile]
unmanaged-devices=except:mac:e6:92:39:49:7b:03,except:interface-name:wwnet0,except:mac:9a:77:29:73:14:f1,except:interface-name:wwnet1,
`

const networkmanager_managed string = `backupFile: true
writeFile: true
Filename: warewulf-default.conf
# This file is autogenerated by warewulf
[connection]
id=default
interface-name=wwnet0
type=ethernet
autoconnect=true
[ethernet]
mac-address=e6:92:39:49:7b:03
# bond
[ipv4]
address=192.168.3.21/24
gateway=192.168.3.1
method=manual

[ipv6]
addr-gen-mode=stable-privacy
method=ignore
never-default=true
backupFile: true
writeFile: true
Filename: warewulf-secondary.conf
# This file is autogenerated by warewulf
[connection]
id=secondary
interface-name=wwnet1
type=ethernet
autoconnect=true
[ethernet]
mac-address=9a:77:29:73:14:f1
# bond
[ipv4]
address=192.168.3.22/24
gateway=192.168.3.1
method=manual
dns=8.8.8.8;8.8.4.4;

[ipv6]
addr-gen-mode=stable-privacy
method=ignore
never-default=true
`
