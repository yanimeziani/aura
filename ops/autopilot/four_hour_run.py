#!/usr/bin/env python3
"""
Nexa Four-Hour Run Orchestrator
Framework for spec-driven, BMAD-based (Build, Measure, Analyze, Decide) codebase audits.
Designed for parallel agent execution.
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

# Configure logging
LOG_DIR = Path("/root/ops/autopilot/results")
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / f"run_{int(time.time())}.log")
    ]
)
logger = logging.getLogger("four_hour_run")

class BMADWorker:
    """Handles the Build-Measure-Analyze-Decide cycle for a specific target."""
    
    def __init__(self, target: Dict[str, Any], root_dir: Path):
        self.target = target
        self.root_dir = root_dir
        self.results = {
            "id": target.get("id", "unknown"),
            "path": target.get("path", "."),
            "status": "pending",
            "phases": {},
            "metrics": {}
        }

    def run_command(self, cmd: str, cwd: Optional[Path] = None) -> Dict[str, Any]:
        """Executes a shell command and captures output."""
        start_time = time.time()
        logger.info(f"[{self.target.get('id')}] Executing: {cmd}")
        
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                cwd=str(cwd or self.root_dir / self.target.get("path", ".")),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=1800 # 30 min timeout per command
            )
            duration = time.time() - start_time
            return {
                "rc": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "duration": duration,
                "success": result.returncode == 0
            }
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "Timeout expired", "duration": 1800}
        except Exception as e:
            return {"success": False, "error": str(e), "duration": time.time() - start_time}

    def build(self) -> bool:
        """Phase 1: Build target."""
        logger.info(f"[{self.target.get('id')}] Phase: BUILD")
        cmd = self.target.get("build_command")
        if not cmd:
            self.results["phases"]["build"] = {"success": True, "message": "No build command defined"}
            return True
            
        res = self.run_command(cmd)
        self.results["phases"]["build"] = res
        return res["success"]

    def measure(self) -> bool:
        """Phase 2: Measure target (tests, lint, metrics)."""
        logger.info(f"[{self.target.get('id')}] Phase: MEASURE")
        commands = self.target.get("measure_commands", [])
        measure_results = []
        all_success = True
        
        for cmd in commands:
            res = self.run_command(cmd)
            measure_results.append({"command": cmd, "result": res})
            if not res["success"]:
                all_success = False
                
        self.results["phases"]["measure"] = {
            "success": all_success,
            "results": measure_results
        }
        return all_success

    def analyze(self) -> bool:
        """Phase 3: Analyze results and metrics."""
        logger.info(f"[{self.target.get('id')}] Phase: ANALYZE")
        analysis = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "findings": []
        }
        
        measure_phase = self.results["phases"].get("measure", {})
        for res in measure_phase.get("results", []):
            output = res["result"].get("stdout", "") + res["result"].get("stderr", "")
            if "FAIL" in output.upper() or "ERROR" in output.upper():
                analysis["findings"].append(f"Potential issues found in command: {res['command']}")

        self.results["phases"]["analyze"] = analysis
        return True

    def decide(self) -> str:
        """Phase 4: Decide next steps."""
        logger.info(f"[{self.target.get('id')}] Phase: DECIDE")
        build_ok = self.results["phases"].get("build", {}).get("success", False)
        measure_ok = self.results["phases"].get("measure", {}).get("success", False)
        
        decision = "UNKNOWN"
        if build_ok and measure_ok:
            decision = "PASS: Ready for deployment/integration"
        elif not build_ok:
            decision = "FAIL: Build failure requires immediate attention"
        else:
            decision = "WARN: Build passed but measurements failed (tests/lint)"
            
        self.results["phases"]["decide"] = {"decision": decision}
        self.results["status"] = "completed"
        return decision

    def execute(self) -> Dict[str, Any]:
        """Executes the full BMAD cycle."""
        try:
            if self.build():
                self.measure()
            self.analyze()
            self.decide()
        except Exception as e:
            logger.error(f"[{self.target.get('id')}] Error during execution: {e}")
            self.results["status"] = "failed"
            self.results["error"] = str(e)
            
        return self.results

class FourHourOrchestrator:
    def __init__(self, spec_path: Path):
        self.spec_path = spec_path
        self.root_dir = Path("/root")
        self.spec = self.load_spec()
        self.results_dir = self.root_dir / "ops" / "autopilot" / "results"
        self.results_dir.mkdir(parents=True, exist_ok=True)
        self.all_iteration_results = []

    def load_spec(self) -> Dict[str, Any]:
        try:
            return json.loads(self.spec_path.read_text())
        except Exception as e:
            logger.error(f"Failed to load spec from {self.spec_path}: {e}")
            sys.exit(1)

    def run(self):
        run_name = self.spec.get("run_name") or self.spec.get("name") or "Unnamed Spec"
        logger.info(f"Starting 4-Hour Run: {run_name}")
        
        target_duration = self.spec.get("global_metrics", {}).get("duration_target_seconds", 14400)
        num_workers = self.spec.get("global_metrics", {}).get("parallel_workers", 4)
        targets = self.spec.get("targets", [])
        
        start_time = time.time()
        iteration_count = 0
        
        while time.time() - start_time < target_duration:
            iteration_count += 1
            iteration_start = time.time()
            logger.info(f"--- Starting Iteration {iteration_count} (Elapsed: {int(iteration_start - start_time)}s) ---")
            
            iteration_results = []
            with ThreadPoolExecutor(max_workers=num_workers) as executor:
                future_to_target = {
                    executor.submit(BMADWorker(target, self.root_dir).execute): target 
                    for target in targets
                }
                
                for future in as_completed(future_to_target):
                    target_data = future_to_target[future]
                    try:
                        result = future.result()
                        iteration_results.append(result)
                        logger.info(f"Iteration {iteration_count}: Completed audit for target: {target_data.get('id')}")
                    except Exception as e:
                        logger.error(f"Iteration {iteration_count}: Target {target_data.get('id')} generated an exception: {e}")

            self.all_iteration_results.append({
                "iteration": iteration_count,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "results": iteration_results
            })
            
            # Save latest iteration summary
            self.save_summary(iteration_results, iteration_count)
            
            # Throttle if iteration was too fast
            elapsed_iteration = time.time() - iteration_start
            if elapsed_iteration < 60:
                logger.info(f"Iteration fast ({int(elapsed_iteration)}s). Sleeping before next pass...")
                time.sleep(60 - elapsed_iteration)

        logger.info(f"Full 4-hour run completed after {iteration_count} iterations.")

    def save_summary(self, results: List[Dict[str, Any]], iteration: int):
        summary_path = self.results_dir / f"summary_iter_{iteration}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        summary = {
            "spec": self.spec.get("run_name") or self.spec.get("name"),
            "iteration": iteration,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "results": results
        }
        summary_path.write_text(json.dumps(summary, indent=2))
        logger.info(f"Iteration {iteration} summary saved to {summary_path}")

def main():
    parser = argparse.ArgumentParser(description="Nexa 4-Hour Run Orchestrator")
    parser.add_argument("--spec", type=str, default="ops/autopilot/specs/default_run.json", help="Path to run spec file")
    args = parser.parse_args()

    spec_path = Path(args.spec)
    if not spec_path.is_absolute():
        spec_path = Path("/root") / args.spec

    orchestrator = FourHourOrchestrator(spec_path)
    orchestrator.run()

if __name__ == "__main__":
    main()
