command! -range LineRef let @+ = expand('%:p') . ':L' . <line1> . (<line1> != <line2> ? '-' . <line2> : '')
