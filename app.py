from flask import Flask, request, jsonify
from flask_cors import CORS
import pdfplumber
import spacy

app = Flask(__name__)
# CORS is essential for Flutter Web to avoid "XMLHttpRequest error"
CORS(app)

# Load NLP Model (en_core_web_sm is installed via requirements.txt)
nlp = spacy.load("en_core_web_sm")

def extract_substance(text):
    """Filters text to isolate Skills and Qualifications only."""
    doc = nlp(text.lower())
    
    # Extract Skills (Nouns/Proper Nouns)
    skills = [token.lemma_ for token in doc if token.pos_ in ["NOUN", "PROPN"] and not token.is_stop]
    
    # Extract Qualifications (Organizations, Degrees, etc.)
    quals = [ent.text for ent in doc.ents if ent.label_ in ["ORG", "LAW", "EVENT"]]
    
    return set(skills + quals), doc

# --- ROUTES ---

@app.route('/')
def health_check():
    """Test this in your browser to see if the server is alive."""
    return jsonify({"status": "Online", "message": "AI Talent Scout Backend is running"}), 200

@app.route('/match', methods=['POST', 'OPTIONS'])
@app.route('/match/', methods=['POST', 'OPTIONS'])
def match_resume():
    try:
        # Check if file exists
        if 'resume' not in request.files:
            return jsonify({"error": "No file uploaded"}), 400

        job_desc_raw = request.form.get('job_desc', '')
        file = request.files['resume']
        
        # 1. Extract PDF Text
        with pdfplumber.open(file) as pdf:
            resume_raw = " ".join([page.extract_text() or "" for page in pdf.pages])

        # 2. NLP Analysis
        jd_substance, jd_doc = extract_substance(job_desc_raw)
        res_substance, res_doc = extract_substance(resume_raw)

        # 3. Logic & Scoring
        found = jd_substance.intersection(res_substance)
        missing = jd_substance.difference(res_substance)

        # Accuracy Formula (60% Keywords + 40% Semantic Intent)
        kw_score = len(found) / len(jd_substance) if jd_substance else 0
        sem_score = nlp(" ".join(list(found))).similarity(nlp(" ".join(list(jd_substance)))) if found else 0
        
        final_score = round(((kw_score * 0.6) + (sem_score * 0.4)) * 100, 2)
        final_score = min(final_score, 100.0)

        # Results are saved to Supabase by the Flutter frontend (with user_id)
        return jsonify({
            "match_percent": final_score,
            "found": list(found)[:15],
            "missing": list(missing)[:15],
            "status": "Analysis Complete"
        })

    except Exception as e:
        print(f"Backend Error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
