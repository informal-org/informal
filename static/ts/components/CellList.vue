<template>
    <ul class="list-group">
        <template v-for="cell in cells">
            <Cell-Edit v-if="$store.state.editCell === cell" v-bind:cell="cell" :key="cell.id"></Cell-Edit>
            <Cell-View v-else v-bind:cell="cell" :key="cell.id"/>
        </template>
        

    </ul>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('CellList', {
    name: 'CellList',
    props: {
        'cells': {type: Array},
    }
});
</script>

<style>
</style>
