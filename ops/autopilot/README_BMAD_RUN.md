# Nexa 4-Hour BMAD Run Orchestrator

This framework provides a spec-driven, parallel execution environment for intensive codebase audits based on the **BMAD (Build, Measure, Analyze, Decide)** methodology.

## Methodology: BMAD v6 (Lean Variation)

1.  **Build**: Compile the target component to ensure structural integrity.
2.  **Measure**: Execute tests, linters, and benchmarking tools to gather raw metrics.
3.  **Analyze**: Process the measurements against predefined thresholds and rules.
4.  **Decide**: Generate actionable decisions (e.g., block release, flag for optimization, approve).

## Usage

### Run a Spec-driven Audit

```bash
python3 ops/autopilot/four_hour_run.py --spec ops/autopilot/specs/default_run.json
```

### Configuration

The orchestrator is driven by JSON specifications located in `ops/autopilot/specs/`.

#### Spec Format
- `targets`: List of components to audit.
    - `id`: Unique identifier.
    - `path`: Path relative to project root.
    - `build_command`: Shell command to build the component.
    - `measure_commands`: List of commands to gather metrics/test results.
- `parallel_workers`: Number of concurrent agents to run.
- `analysis_rules`: Thresholds for automated decision making.

## Output

- **Logs**: Detailed execution logs are stored in `ops/autopilot/results/run_<timestamp>.log`.
- **Summaries**: JSON summaries of the BMAD cycle for all targets are saved to `ops/autopilot/results/summary_<timestamp>.json`.

## Parallelism

The orchestrator uses `concurrent.futures.ThreadPoolExecutor` to manage multiple agent workers in parallel, maximizing throughput during the 4-hour window.
