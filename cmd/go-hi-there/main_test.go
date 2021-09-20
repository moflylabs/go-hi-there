package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHiThere(t *testing.T) {

	got := HiThere()
	want := "Hi there!"
	assert.Equal(t, got, want)

}
