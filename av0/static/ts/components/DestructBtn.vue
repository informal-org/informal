<template>
    <button title="Delete" type="button" class="DeleteBtn LinkBtn btn-md" aria-label="Delete" v-on:click="cell.destruct()">
        <span>
        <i class="fas fa-trash-alt"></i> Delete
        </span>
    </button>
</template>

<script lang="ts">
import Vue from "vue";
import {Value} from "../engine/engine";

export default Vue.component('DestructBtn', {
    name: 'DestructBtn',
    props: {
        'cell': {type: Value},
    },
});
</script>

<style>
</style>
