import os
import subprocess
import time
import json
import difflib
from pathlib import Path
import argparse

def compute_levenshtein(s1, s2):
    if len(s1) < len(s2):
        return compute_levenshtein(s2, s1)
    if len(s2) == 0:
        return len(s1)
    previous_row = range(len(s2) + 1)
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row
    return previous_row[-1]

def evaluate(gt_md, pred_md):
    # Length Ratio
    len_ratio = len(pred_md) / max(len(gt_md), 1)
    
    # Edit Distance (Levenshtein) - normalized by max length
    edit_dist = compute_levenshtein(gt_md, pred_md)
    normalized_edit_dist = 1.0 - (edit_dist / max(len(gt_md), len(pred_md), 1))
    
    # SequenceMatcher ratio
    matcher = difflib.SequenceMatcher(None, gt_md, pred_md)
    similarity = matcher.ratio()
    
    return {
        "length_ratio": round(len_ratio, 3),
        "normalized_edit_distance": round(normalized_edit_dist, 3),
        "similarity": round(similarity, 3)
    }

def main():
    parser = argparse.ArgumentParser(description="Run Flow_CLI Benchmark")
    parser.add_argument("--hf_dataset", type=str, default=None, help="HuggingFace dataset name (e.g. datalab-to/marker_benchmark)")
    parser.add_argument("--dataset_dir", type=str, default="test_data", help="Directory containing PDF files (used if hf_dataset is not provided)")
    parser.add_argument("--gt_dir", type=str, default="test_gt", help="Directory containing Ground Truth MD files (used if hf_dataset is not provided)")
    parser.add_argument("--max_items", type=int, default=10, help="Max items to process from HuggingFace dataset")
    args = parser.parse_args()

    project_root = Path(__file__).parent.parent
    cli_exec = project_root / ".build" / "debug" / "Flow_CLI"
    
    if not cli_exec.exists():
        print(f"❌ Error: Flow_CLI executable not found at {cli_exec}")
        print("Please run `swift build` first.")
        return

    out_dir = project_root / "benchmarks" / "output"
    out_dir.mkdir(parents=True, exist_ok=True)
    
    results = {}

    if args.hf_dataset:
        try:
            from datasets import load_dataset
        except ImportError:
            print("❌ Error: `datasets` module not found.")
            print("Please run `pip install datasets` to use HuggingFace datasets.")
            return

        print(f"📥 Loading dataset {args.hf_dataset} from HuggingFace...")
        ds = load_dataset(args.hf_dataset, split="train")
        
        # Limit the number of items for benchmarking
        total_items = min(len(ds), args.max_items)
        
        for i in range(total_items):
            sample = ds[i]
            pdf_bytes = sample.get("pdf")
            if not pdf_bytes:
                continue
                
            pdf_name = f"hf_sample_{i}.pdf"
            tmp_pdf_path = out_dir / pdf_name
            with open(tmp_pdf_path, "wb") as f:
                f.write(pdf_bytes)
                
            # Naive GT extraction if available in the dataset format
            gt_text = ""
            if "gt_blocks" in sample:
                try:
                    import re
                    blocks = json.loads(sample["gt_blocks"])
                    html_text = "\\n\\n".join([b.get("html", "") for b in blocks])
                    # Strip HTML tags so it matches Markdown output more fairly
                    gt_text = re.sub(r'<[^>]+>', '', html_text)
                except:
                    pass
            elif "gt_markdown" in sample:
                gt_text = sample["gt_markdown"]

            print(f"🔄 Processing HF sample {i+1}/{total_items}...")
            out_md = out_dir / f"hf_sample_{i}.md"
            
            start_time = time.time()
            process = subprocess.run(
                [str(cli_exec), str(tmp_pdf_path), str(out_md)],
                capture_output=True,
                text=True
            )
            elapsed = time.time() - start_time
            
            if process.returncode != 0:
                print(f"❌ Failed to process HF sample {i}")
                print(process.stderr)
                continue
                
            if not out_md.exists():
                print(f"❌ Output MD not found for HF sample {i}")
                continue
                
            with open(out_md, "r", encoding="utf-8") as f:
                pred_text = f.read()
                
            scores = {"time_seconds": round(elapsed, 2)}
            if gt_text:
                eval_scores = evaluate(gt_text, pred_text)
                scores.update(eval_scores)
                print(f"✅ HF sample {i} -> Similarity: {scores.get('similarity', 0)}, Time: {scores['time_seconds']}s")
            else:
                print(f"✅ HF sample {i} processed successfully (No GT available). Time: {scores['time_seconds']}s")
                
            results[pdf_name] = scores
            
            # Clean up temp PDF
            tmp_pdf_path.unlink()

    else:
        dataset_dir = Path(args.dataset_dir)
        gt_dir = Path(args.gt_dir)
        
        if not dataset_dir.exists():
            print(f"⚠️ Dataset directory {dataset_dir} does not exist. Creating it.")
            dataset_dir.mkdir(parents=True)
            return
            
        pdf_files = list(dataset_dir.glob("*.pdf"))
        if not pdf_files:
            print(f"⚠️ No PDF files found in {dataset_dir}.")
            return
            
        for pdf_file in pdf_files:
            print(f"🔄 Processing {pdf_file.name}...")
            out_md = out_dir / f"{pdf_file.stem}.md"
            
            start_time = time.time()
            process = subprocess.run(
                [str(cli_exec), str(pdf_file), str(out_md)],
                capture_output=True,
                text=True
            )
            elapsed = time.time() - start_time
            
            if process.returncode != 0:
                print(f"❌ Failed to process {pdf_file.name}")
                print(process.stderr)
                continue
                
            if not out_md.exists():
                print(f"❌ Output MD not found for {pdf_file.name}")
                continue
                
            # Read predicted markdown
            with open(out_md, "r", encoding="utf-8") as f:
                pred_text = f.read()
                
            gt_md_file = gt_dir / f"{pdf_file.stem}.md"
            scores = {"time_seconds": round(elapsed, 2)}
            
            if gt_md_file.exists():
                with open(gt_md_file, "r", encoding="utf-8") as f:
                    gt_text = f.read()
                eval_scores = evaluate(gt_text, pred_text)
                scores.update(eval_scores)
                print(f"✅ {pdf_file.name} -> Similarity: {scores['similarity']}, Time: {scores['time_seconds']}s")
            else:
                print(f"✅ {pdf_file.name} processed successfully (No GT available). Time: {scores['time_seconds']}s")
                
            results[pdf_file.name] = scores
        
    # Generate Report
    report_file = project_root / "benchmarks" / "report.json"
    with open(report_file, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=4)
        
    print(f"📊 Benchmark report saved to {report_file}")

if __name__ == "__main__":
    main()
