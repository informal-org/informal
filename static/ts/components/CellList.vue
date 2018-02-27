<template>
    <ul class="list-group CellList">
        <template v-for="cell in cells">
            <template v-if="$store.state.editCell === cell" >
                <Cell-Edit v-if="cell.isRootChild()" v-bind:cell="cell" :key="cell.id"></Cell-Edit>
                <Inline-Edit v-else v-bind:cell="cell" :key="cell.id"></Inline-Edit>
            </template>
            <Cell-View v-else v-bind:cell="cell" :key="cell.id"/>
        </template>
        <Add-Cell-Btn v-bind:group="this.addTo" v-if="this.addTo"></Add-Cell-Btn>
    </ul>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('CellList', {
    name: 'CellList',
    props: {
        'cells': {type: Array},
        'addTo': {type: Group}
    }
});
</script>

<style>
</style>
