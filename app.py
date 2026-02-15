from flask import Flask, request, jsonify
from flask_cors import CORS
import pdfplumber
import spacy
from supabase import create_client, Client
import os
from datetime import datetime

app = Flask(__name__)
# CORS is essential for Flutter Web to avoid "XMLHttpRequest error"
CORS(app)

# --- 1. FIXED SUPABASE CONFIGURATION ---
# Corrected 'subabase' to 'supabase'
SUPABASE_URL = "https://zrodayjdpcqiilnxerix.supabase.co"
# Use your Service Role Key for backend operations to bypass RLS
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpyb2RheWpkcGNxaWlsbnhlcml4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA5ODg5ODYsImV4cCI6MjA4NjU2NDk4Nn0.4GQZV2vZHqMBFsB4bYzEu2GO2bUwnjRYdboCQXXfMBY" 
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Load NLP Model
try:
    nlp = spacy.load("en_core_web_md")
except:
    # Fallback if md model isn't installed
    nlp = spacy.load("en_core_web_sm")

def extract_substance(text):
    """Filters text to isolate Skills and Qualifications only."""
    doc = nlp(text.lower())
    
    # Extract Skills (Nouns/Proper Nouns)
    skills = [token.lemma_ for token in doc if token.pos_ in ["NOUN", "PROPN"] and not token.is_stop]
    
    # Extract Qualifications (Organizations, Degrees, etc.)
    quals = [ent.text for ent in doc.ents if ent.label_ in ["ORG", "LAW", "EVENT"]]
    
    return set(skills + quals), doc

def save_to_supabase(resume_text, job_desc, match_percent, found, missing, file_name):
    """Saves results into your Supabase tables."""
    try:
        # 1. Insert into 'resumes'
        resume_res = supabase.table('resumes').insert({
            'file_name': file_name,
            'extracted_text': resume_text[:5000],
            'file_size_kb': len(resume_text) // 1024,
        }).execute()
        resume_id = resume_res.data[0]['id']

        # 2. Insert into 'job_descriptions'
        jd_res = supabase.table('job_descriptions').insert({
            'title': 'AI Scout Analysis',
            'description': job_desc[:1000],
            'input_mode': 'api_request',
        }).execute()
        job_desc_id = jd_res.data[0]['id']

        # 3. Insert into 'analysis_results'
        supabase.table('analysis_results').insert({
            'resume_id': resume_id,
            'job_description_id': job_desc_id,
            'match_percent': match_percent,
            'matched_skills': list(found),
            'missing_skills': list(missing),
            'matched_count': len(found),
            'missing_count': len(missing),
            'status': 'completed',
        }).execute()
        
        return True
    except Exception as e:
        print(f"Supabase Save Error: {e}")
        return False

# --- 2. UPDATED ROUTES TO PREVENT 404 ---

@app.route('/')
def health_check():
    """Test this in your browser to see if the server is alive."""
    return jsonify({"status": "Online", "message": "AI Talent Scout Backend is running"}), 200

@app.route('/match', methods=['POST', 'OPTIONS'])
@app.route('/match/', methods=['POST', 'OPTIONS']) # Added trailing slash support
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

        # 4. Save to Database
        save_to_supabase(
            resume_text=resume_raw,
            job_desc=job_desc_raw,
            match_percent=final_score,
            found=found,
            missing=missing,
            file_name=file.filename
        )

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
    # Use host='0.0.0.0' to allow connections from your Flutter app
    app.run(host='0.0.0.0', port=5000, debug=False)
