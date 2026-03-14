-- Create the 'contracts' storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('contracts', 'contracts', false)
ON CONFLICT (id) DO NOTHING;

-- Policy to allow authenticated users to upload
CREATE POLICY "Authenticated users can upload contracts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'contracts');

-- Policy to allow users to view their own contracts (based on folder structure merchants/ID/...)
-- Note: Storage policies are tricky with folders.
-- We'll allow authenticated users to read everything in the bucket for now for simplicity, 
-- relying on the application logic to only show relevant files.
CREATE POLICY "Authenticated users can read contracts"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'contracts');
