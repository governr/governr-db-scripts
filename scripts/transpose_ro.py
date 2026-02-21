import pandas as pd

INPUT_CSV = "risk_controls.csv"
OUTPUT_CSV = "risk_controls_long.csv"

df = pd.read_csv(INPUT_CSV)
df.columns = df.columns.str.strip()

score_map = {
    "Score 0 (Gap)": (0, "Gap", "R01"),
    "Score 25 (Weak)": (25, "Weak", "R02"),
    "Score 50 (Baseline)": (50, "Baseline", "R03"),
    "Score 75 (Robust)": (75, "Robust", "R04"),
    "Score 100 (Compliant)": (100, "Compliant", "R05"),
}

score_cols = list(score_map.keys())

out = df.melt(
    id_vars=["Risk ID", "Asset Type", "Risk Name"],
    value_vars=score_cols,
    var_name="Score Level",
    value_name="Response Option",
)

out["Score"] = out["Score Level"].map(lambda x: score_map[x][0])
out["Maturity Level"] = out["Score Level"].map(lambda x: score_map[x][1])
out["Response Suffix"] = out["Score Level"].map(lambda x: score_map[x][2])

# ✅ UNIQUE CODE PER RESPONSE (e.g. "DST-Q01-R01", "DST-Q01-R02")
out["Response Code"] = out["Risk ID"] + "-" + out["Response Suffix"]

out = out.drop(columns=["Score Level", "Response Suffix"]).dropna(subset=["Response Option"])
out["Response Option"] = out["Response Option"].astype(str).str.strip()
out = out[out["Response Option"] != ""]

# Calculate sequence from score (0,25,50,75,100 -> 1,2,3,4,5)
out["Sequence"] = (out["Score"] / 25 + 1).astype(int)

# Rename columns to match seed format
out = out.rename(columns={
    "Response Code": "atqro_code",
    "Risk ID": "atq_code",
    "Maturity Level": "atqro_label",
    "Response Option": "atqro_description",
    "Score": "atqro_score_risk",
    "Sequence": "atqro_sequence"
})

# Add is_default (baseline = Y, others = N)
out["atqro_is_default"] = out["atqro_label"].apply(lambda x: "Y" if x == "Baseline" else "N")

# Add is_active (all Y)
out["atqro_is_active"] = "Y"

# Final column order for seed
out = out[["atq_code", "atqro_code", "atqro_label", "atqro_description", 
           "atqro_sequence", "atqro_is_default", "atqro_is_active", "atqro_score_risk"]]
out = out.sort_values(["atq_code", "atqro_sequence"])

# Output to data folder for seed
OUTPUT_CSV = "../data/assessment_template_question_response_option.csv"
out.to_csv(OUTPUT_CSV, index=False)
print(f"✅ {len(out)} unique responses → {OUTPUT_CSV}")
print(out.head(10))
