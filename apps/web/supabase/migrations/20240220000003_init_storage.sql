-- Create the 'contracts' storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('contracts', 'contracts', false)
ON CONFLICT (id) DO NOTHING;

-- Policies for 'contracts' bucket
CREATE POLICY "Authenticated users can upload contracts"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'contracts');

CREATE POLICY "Authenticated users can read contracts"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'contracts');

CREATE POLICY "Authenticated users can update contracts"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'contracts');

CREATE POLICY "Authenticated users can delete contracts"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'contracts');
