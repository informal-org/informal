<template>
    <ul class="list-group">
        <template v-for="cell in cells">
            <template v-if="cell.type == 'group'">
                <Cell-List :key="cell.id" v-bind:group="cell"></Cell-List>
            </template>
            <template v-else>
                <Cell-Edit v-if="$store.state.editCell === cell" :key="cell.id" v-bind:cell="cell"></Cell-Edit>
                <Cell-View v-else :key="cell.id" v-bind:cell="cell"></Cell-View>
            </template>
        </template>
        <!--<template v-if="onadd !== undefined">-->
            <!--<a class="list-group-item list-group-item-action AddItem" @mousedown="addNewCell">-->
                <!--<i class="fas fa-plus"></i>-->
                <!--Add Item-->
                <!--</a>-->
        <!--</template>-->
    </ul>
</template>

<script lang="ts">
import Vue from "vue";
import {Group, Value} from "../engine/engine";

export default Vue.component('CellList', {
    name: 'CellList',
    props: {
        'cells': {type: Array},
    },
    methods: {
        addCell: function(event: Event) {
            // todo: Vuex this
            // let c = new Cell("", "test", this.cellgroup.env, "hello");
            // let c = this.cellgroup.env.createCell("", "", "")
            // this.cellgroup.addChild(c);
            // window.lastAddedIndex = this.cellgroup.env.all_cells.indexOf(c);
        },
    },
});
</script>

<style>
</style>
