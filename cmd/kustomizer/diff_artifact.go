/*
Copyright 2021 Stefan Prodan

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sigs.k8s.io/yaml"
	"strings"

	"github.com/spf13/cobra"

	"github.com/stefanprodan/kustomizer/pkg/registry"
)

var diffArtifactCmd = &cobra.Command{
	Use:   "artifact",
	Short: "Diff compares the two artifacts and prints the differences between the Kubernetes resources to stdout.",
	Example: `  kustomizer diff artifact <oci url1> <oci url2>

  # Diff artifact by tag
  kustomizer diff artifact oci://registry/org/repo:v1 oci://registry/org/repo:v2

  # Diff artifact by digest
  kustomizer diff artifact oci://registry/org/repo@sha245:<digest-1> oci://registry/org/repo@sha245:<digest-2>
`,
	RunE: runDiffArtifactCmd,
}

func init() {
	diffCmd.AddCommand(diffArtifactCmd)
}

func runDiffArtifactCmd(cmd *cobra.Command, args []string) error {
	if len(args) != 2 {
		return fmt.Errorf("you must specify two artifact URLs")
	}

	tmpDir, err := os.MkdirTemp("", *kubeconfigArgs.Namespace)
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)

	ctx, cancel := context.WithTimeout(context.Background(), rootArgs.timeout)
	defer cancel()

	files := []string{}
	for i, ociURL := range args {
		url, err := registry.ParseURL(ociURL)
		if err != nil {
			return err
		}

		data, _, err := registry.Pull(ctx, url)
		if err != nil {
			return fmt.Errorf("pulling %s failed: %w", url, err)
		}
		res, _ := yaml.Marshal(data)
		resPath := filepath.Join(tmpDir, fmt.Sprintf("%d.yaml", i))
		if err := os.WriteFile(resPath, res, 0644); err != nil {
			return err
		}
		files = append(files, resPath)
	}

	out, _ := exec.Command("diff", "-N", "-u", files[0], files[1]).Output()
	for i, line := range strings.Split(string(out), "\n") {
		if i > 1 && len(line) > 0 {
			rootCmd.Println(line)
		}
	}

	return nil
}
