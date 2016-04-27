read -d ":" filename | xargs
hexdump -v -e '1/1 "%06_ad" "\t"' -e '4/1 "%02x " " | "' -e '4/1 "%_p" "\n"'
