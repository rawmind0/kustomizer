package engine

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// KubectlExecutor an executor that shells out to run commands
type KubectlExecutor struct {
	envVars []string
}

// NewKubectlExecutor creates a new executor that runs kubectl commands
func NewKubectlExecutor(envVars []string) KubectlExecutor {
	return KubectlExecutor{
		envVars: envVars,
	}
}

// Exec execute the kubectl command with the specified args
func (e KubectlExecutor) Exec(ctx context.Context, args ...string) error {
	cmd := exec.CommandContext(ctx, "kubectl", args...)
	if len(e.envVars) > 0 {
		cmd.Env = e.envVars
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// Get execute the kubectl command with the specified args and returns the output as string
func (e KubectlExecutor) Get(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "kubectl", args...)
	if len(e.envVars) > 0 {
		cmd.Env = e.envVars
	}
	if output, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("%s", string(output))
	} else {
		return strings.TrimSuffix(string(output), "\n"), nil
	}
}

// Pipe execute the kubectl command by piping the yaml arg
func (e KubectlExecutor) Pipe(ctx context.Context, yaml string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "kubectl", args...)
	if len(e.envVars) > 0 {
		cmd.Env = e.envVars
	}
	cmd.Stdin = strings.NewReader(yaml)
	if output, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("%s", string(output))
	} else {
		return strings.TrimSuffix(string(output), "\n"), nil
	}
}
