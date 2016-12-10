# pulito
A script to back up and check AWS S3 buckets for viruses with clamav

Caveats/Admissions of lazyness
 - s3fs mounting in not optimized.
 - Can be _very_ slow if there are a lot of little files; see above!
 - Little effort put in to log tidyness. 
