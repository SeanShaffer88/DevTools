# Media Attribution Catalog V1

media/catalog.json records original locally generated PNG and PCM WAV fixtures. Source, author, license declaration, modification, requiredCredits, root-relative path and actual hash are explicit. Stated local fixture rights are declarations, not a legal ownership or redistribution certificate. No third-party media was downloaded.

resources/Test-MediaAttribution.ps1 -Root <media-root> -CatalogPath <catalog> [-CreditsPath <new-file>] verifies bounded file identities offline. Missing required rights metadata is Unknown (3); corrupt/missing file is Fail (2); unsafe path/labels/setup is 125. Complete declared records with matching hashes pass metadata/identity checks only. Credits are plain text, emitted only after every record passes, with bounded labels and no local absolute paths or control characters. No HTML or automatic attribution publication occurs. Read helper help before use.
