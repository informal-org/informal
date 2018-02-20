<template>
    <ul class="list-group">
        <template v-for="cell in cells">
            <template v-if="cell.type == 'group'">
                <Cell-List :key="cell.id" v-bind:group="cell"></Cell-List>
            </template>
            <template v-else-if="cell.type == 'table'">
                <Cell-Table :key="cell.id" v-bind:table="cell"></Cell-Table>
            </template>
            <template v-else>
                <Cell-Edit v-if="$store.state.editCell === cell" :key="cell.id" v-bind:cell="cell"></Cell-Edit>
                <Cell-View v-else :key="cell.id" v-bind:cell="cell"></Cell-View>
            </template>
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
