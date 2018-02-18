<template>
    <button type="button" class="close" aria-label="Close" v-on:click="cell.destruct()">
        <span aria-hidden="true">&times;</span>
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
