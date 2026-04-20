package tree_sitter_jade_test

import (
	"testing"

	tree_sitter "github.com/smacker/go-tree-sitter"
	"github.com/tree-sitter/tree-sitter-jade"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_jade.Language())
	if language == nil {
		t.Errorf("Error loading Jade grammar")
	}
}
