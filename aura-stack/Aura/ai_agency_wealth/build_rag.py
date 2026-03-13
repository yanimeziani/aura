import os
import glob
from langchain_community.document_loaders import TextLoader, DirectoryLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_ollama import OllamaEmbeddings
from langchain_community.vectorstores import Chroma

# Configuration
CHROMA_PATH = os.path.join(os.path.expanduser("~"), ".second_brain_db")
DATA_PATHS = [
    os.path.join(os.path.expanduser("~"), "ai_agency_wealth"),
    os.path.join(os.path.expanduser("~"), "Documents/dev")
]

def build_second_brain():
    print("🧠 INITIATING SECOND BRAIN INDEXING...")
    
    # 1. Load Documents
    documents = []
    for path in DATA_PATHS:
        print(f"📄 Loading files from: {path}")
        # Use a more robust loader for code and text
        loader = DirectoryLoader(
            path, 
            glob="**/*.{py,md,txt,sh,ts,tsx,json}", 
            loader_cls=TextLoader,
            loader_kwargs={'encoding': 'utf-8', 'autodetect_encoding': True},
            silent_errors=True
        )
        documents.extend(loader.load())
    
    print(f"📚 Total documents loaded: {len(documents)}")
    
    # 2. Split Text
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=1000,
        chunk_overlap=100,
        length_function=len,
        add_start_index=True,
    )
    chunks = text_splitter.split_documents(documents)
    print(f"✂️ Split into {len(chunks)} chunks.")
    
    # 3. Create Vector Store (using Ollama local embeddings)
    print("🌀 Generating embeddings and saving to ChromaDB (using local Ollama)...")
    embeddings = OllamaEmbeddings(model="gemma3:latest")
    
    # Clear existing DB
    if os.path.exists(CHROMA_PATH):
        import shutil
        shutil.rmtree(CHROMA_PATH)
        
    db = Chroma.from_documents(
        chunks, embeddings, persist_directory=CHROMA_PATH
    )
    
    print(f"✅ SECOND BRAIN READY at {CHROMA_PATH}")
    return db

if __name__ == "__main__":
    try:
        build_second_brain()
    except Exception as e:
        print(f"❌ Error building second brain: {e}")
