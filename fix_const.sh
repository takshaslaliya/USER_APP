#!/bin/bash
FILES=$(find lib -name "*.dart")
for FILE in $FILES; do
    sed -i -E 's/const (EdgeInsets.*)$/\1/g' "$FILE"
    sed -i -E 's/const (SizedBox.*)$/\1/g' "$FILE"
    sed -i -E 's/const (LinearGradient.*)$/\1/g' "$FILE"
    sed -i -E 's/const (Icon.*)$/\1/g' "$FILE"
    sed -i -E 's/const (BoxShadow.*)$/\1/g' "$FILE"
    sed -i -E 's/const (Text.*)$/\1/g' "$FILE"
    sed -i -E 's/const (Padding.*)$/\1/g' "$FILE"
    sed -i -E 's/const (Row.*)$/\1/g' "$FILE"
    sed -i -E 's/const (Column.*)$/\1/g' "$FILE"
    sed -i -E 's/const (Container.*)$/\1/g' "$FILE"
done
