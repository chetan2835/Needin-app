-- Create legal_documents table
CREATE TABLE IF NOT EXISTS public.legal_documents (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    slug VARCHAR(255) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    version VARCHAR(50) NOT NULL,
    effective_date DATE NOT NULL,
    content TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create user_legal_acceptances table
CREATE TABLE IF NOT EXISTS public.user_legal_acceptances (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES public.legal_documents(id) ON DELETE CASCADE,
    accepted_version VARCHAR(50) NOT NULL,
    accepted_at TIMESTAMPTZ DEFAULT NOW(),
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, document_id, accepted_version)
);

-- Enable RLS
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_legal_acceptances ENABLE ROW LEVEL SECURITY;

-- Policies for legal_documents
CREATE POLICY "Legal documents are viewable by everyone." ON public.legal_documents
    FOR SELECT USING (true);

-- Policies for user_legal_acceptances
CREATE POLICY "Users can view their own acceptances." ON public.user_legal_acceptances
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own acceptances." ON public.user_legal_acceptances
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create trigger for updated_at
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON public.legal_documents
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Seed data (initial dummy data, the actual content is managed offline or can be seeded here)
-- We will insert the basic metadata so the IDs and slugs exist.
INSERT INTO public.legal_documents (slug, title, version, effective_date, content, is_active)
VALUES 
('terms-and-conditions', 'Terms and Conditions', '1.0', '2026-05-06', 'Content is synced from offline bundle.', true),
('privacy-policy', 'Privacy Policy', '1.0', '2026-05-06', 'Content is synced from offline bundle.', true),
('delivery-agreement', 'Needin Express Delivery Agreement', '1.0', '2026-05-06', 'Content is synced from offline bundle.', true),
('cancellation-policy', 'Cancellation & Refund Policy', '1.0', '2026-05-06', 'Content is synced from offline bundle.', true)
ON CONFLICT (slug) DO UPDATE 
SET title = EXCLUDED.title, version = EXCLUDED.version, effective_date = EXCLUDED.effective_date, is_active = EXCLUDED.is_active;
