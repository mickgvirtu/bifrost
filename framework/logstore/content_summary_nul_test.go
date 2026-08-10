package logstore

import (
	"testing"

	"github.com/maximhq/bifrost/core/schemas"
	"github.com/stretchr/testify/assert"
)

// TestBuildContentSummary_StripsNUL reproduces the Postgres SQLSTATE 22021
// log-drop: request text can contain a NUL, which lands in ContentSummary via
// BuildContentSummary, and Postgres text rejects a raw NUL. BuildContentSummary
// must strip it. The NUL is built from rune(0) so this source file stays
// NUL-free (the go toolchain rejects a literal 0x00 in source).
func TestBuildContentSummary_StripsNUL(t *testing.T) {
	nul := string(rune(0)) // raw 0x00, without a literal NUL in the source
	contentWithNUL := "see `" + nul + "` etc. jsonb rejects"
	log := &Log{
		InputHistoryParsed: []schemas.ChatMessage{
			{Role: schemas.ChatMessageRoleUser, Content: &schemas.ChatMessageContent{ContentStr: &contentWithNUL}},
		},
	}

	summary := log.BuildContentSummary()

	assert.NotContains(t, summary, nul,
		"BuildContentSummary must not emit a raw NUL (Postgres text rejects 0x00)")
	assert.Contains(t, summary, "see `", "non-NUL text must be preserved")
}
